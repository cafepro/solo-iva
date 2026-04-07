require "pdf-reader"

class PdfInvoiceParser
  class ParseError < StandardError; end

  IVA_RATES = [ 21, 10, 5, 4, 0 ].freeze

  def initialize(pdf_path_or_io)
    @source = pdf_path_or_io
  end

  def parse
    text = extract_text
    result = extract_from_text(text)

    if result[:lines].empty?
      result = gemini_fallback(text)
    end

    result
  rescue => e
    raise ParseError, "No se pudo parsear el PDF: #{e.message}"
  end

  private

  def extract_text
    reader = PDF::Reader.new(@source)
    reader.pages.map(&:text).join("\n")
  end

  def extract_from_text(text)
    {
      invoice_number: extract_invoice_number(text),
      invoice_date:   extract_date(text),
      issuer_name:    extract_issuer(text),
      issuer_nif:     extract_nif(text),
      lines:          extract_iva_lines(text)
    }
  end

  def extract_invoice_number(text)
    match = text.match(/(?:factura|n[uú]mero|n[oº°]\.?)\s*:?\s*([A-Z0-9\/\-]+)/i)
    match&.[](1)
  end

  def extract_date(text)
    match = text.match(/(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})/)
    return nil unless match
    Date.new(match[3].to_i, match[2].to_i, match[1].to_i)
  rescue ArgumentError
    nil
  end

  def extract_nif(text)
    match = text.match(/(?:NIF|CIF|DNI)\s*:?\s*([A-Z0-9]{8,9}[A-Z]?)/i)
    match&.[](1)
  end

  def extract_issuer(text)
    # First non-empty line before NIF/CIF usually is the company name
    lines = text.split("\n").map(&:strip).reject(&:empty?)
    nif_line_idx = lines.index { |l| l.match?(/NIF|CIF|DNI/i) }
    nif_line_idx&.positive? ? lines[nif_line_idx - 1] : lines.first
  end

  def extract_iva_lines(text)
    lines = []

    IVA_RATES.each do |rate|
      # Match patterns like "IVA 21%" or "21,00 %" followed by amounts
      pattern = /#{rate}[\.,]?0*\s*%[^\d]*([\d\.]+[\.,]\d{2})/i
      match = text.match(pattern)
      next unless match

      base = parse_amount(match[1])
      next unless base&.positive?

      lines << {
        iva_rate:       rate,
        base_imponible: base,
        iva_amount:     (base * rate / 100.0).round(2)
      }
    end

    # If no IVA lines found, try to find base + total and infer 21%
    if lines.empty?
      base = infer_base(text)
      if base
        lines << {
          iva_rate:       21,
          base_imponible: base,
          iva_amount:     (base * 0.21).round(2)
        }
      end
    end

    lines
  end

  def infer_base(text)
    # Look for "base imponible" label
    match = text.match(/base\s+imponible[^\d]*([\d\.]+[\.,]\d{2})/i)
    parse_amount(match[1]) if match
  end

  def parse_amount(str)
    return nil if str.nil?
    # Handle both "1.234,56" and "1,234.56" formats
    cleaned = if str.match?(/\.\d{3}[,]\d{2}$/) || str.match?(/^\d{1,3}(\.\d{3})*,\d{2}$/)
      str.gsub(".", "").gsub(",", ".")
    else
      str.gsub(",", "")
    end
    cleaned.to_f
  end

  def gemini_fallback(text)
    api_key = Rails.application.credentials.gemini_api_key
    return empty_result unless api_key.present?

    conn = Faraday.new("https://generativelanguage.googleapis.com") do |f|
      f.request :json
      f.response :json
    end

    prompt = <<~PROMPT
      Analiza el siguiente texto de una factura española y extrae los datos en formato JSON.
      Devuelve SOLO el JSON, sin explicaciones.

      Formato esperado:
      {
        "invoice_number": "string o null",
        "invoice_date": "YYYY-MM-DD o null",
        "issuer_name": "string o null",
        "issuer_nif": "string o null",
        "lines": [
          { "iva_rate": 21, "base_imponible": 100.00, "iva_amount": 21.00 }
        ]
      }

      Texto de la factura:
      #{text.truncate(3000)}
    PROMPT

    response = conn.post(
      "/v1beta/models/gemini-1.5-flash:generateContent",
      {
        contents: [ { parts: [ { text: prompt } ] } ]
      },
      { "x-goog-api-key" => api_key }
    )

    raw_json = response.body.dig("candidates", 0, "content", "parts", 0, "text")
    clean_json = raw_json&.gsub(/```json\n?|\n?```/, "")
    parsed = JSON.parse(clean_json || "{}")

    {
      invoice_number: parsed["invoice_number"],
      invoice_date:   parsed["invoice_date"] ? Date.parse(parsed["invoice_date"]) : nil,
      issuer_name:    parsed["issuer_name"],
      issuer_nif:     parsed["issuer_nif"],
      lines:          (parsed["lines"] || []).map(&:symbolize_keys)
    }
  rescue => e
    Rails.logger.warn("Gemini fallback failed: #{e.message}")
    empty_result
  end

  def empty_result
    { invoice_number: nil, invoice_date: nil, issuer_name: nil, issuer_nif: nil, lines: [] }
  end
end
