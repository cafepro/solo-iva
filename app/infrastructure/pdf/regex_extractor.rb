require "pdf-reader"

module Pdf
  # Extracts invoice data from a PDF using regex heuristics.
  # Returns a PdfExtractionResult. Best-effort: callers should check for
  # missing critical fields and fall back to an AI extractor when needed.
  class RegexExtractor
    IVA_RATES = [21, 10, 5, 4, 0].freeze

    MONTHS_ES = {
      "enero" => 1, "febrero" => 2, "marzo" => 3, "abril" => 4,
      "mayo" => 5, "junio" => 6, "julio" => 7, "agosto" => 8,
      "septiembre" => 9, "octubre" => 10, "noviembre" => 11, "diciembre" => 12
    }.freeze

    def initialize(source)
      @source = source
    end

    def extract
      text = read_text
      PdfExtractionResult.new(
        invoice_number: extract_invoice_number(text),
        invoice_date:   extract_date(text),
        issuer_name:    extract_issuer(text),
        issuer_nif:     extract_nif(text),
        lines:          extract_iva_lines(text)
      )
    end

    private

    def read_text
      reader = PDF::Reader.new(@source)
      reader.pages.map(&:text).join("\n")
    end

    def extract_invoice_number(text)
      # "Nº Factura: S265022" / "Nº Fra.: X"
      two_word = text.match(/n[oº°]\.?\s+(?:factura|fra)\.?\s*:?\s*([\w][A-Z0-9\/\-_]{1,24})/i)
      return two_word[1] if two_word

      # "Factura nº: F-001" / "Número: X"
      one_word = text.match(/(?:factura\s+n[ouº°]\.?|n[uú]mero)\s*:?\s*([\w][A-Z0-9\/\-_]{1,24})/i)
      return one_word[1] if one_word

      # Standalone alphanumeric token — letters + digits, mixed case, no spaces
      # e.g. OM4VMAJ0160440, S265022, F001234
      # Require at least 2 letters and 4 digits to avoid matching random words
      mixed = text.match(/\b([A-Z]{1,6}\d{1,6}[A-Z]{1,6}\d{3,12}|[A-Z]\d{5,9})\b/)
      return mixed[1] if mixed

      # Separator-based token: 2026/001, F-2026-01 (not a date)
      dated = text.match(/\b([A-Z]{1,4}\d{2,4}[-\/]\d{1,6}(?:[-\/][A-Z0-9]{1,6})?)\b/i)
      return dated[1] if dated

      nil
    end

    def extract_date(text)
      # Written date: "04 de Enero de 2026"
      written = text.match(/(\d{1,2})\s+de\s+([a-záéíóú]+)\s+de\s+(\d{4})/i)
      if written
        month = MONTHS_ES[written[2].downcase]
        return Date.new(written[3].to_i, month, written[1].to_i) if month
      end

      # Numeric with explicit label first, then any date token
      match = text.match(/fecha\s*:?\s*(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})/i) ||
              text.match(/(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})/)
      return nil unless match

      day      = match[-3].to_i
      month    = match[-2].to_i
      raw_year = match[-1]
      year     = raw_year.length == 2 ? 2000 + raw_year.to_i : raw_year.to_i
      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end

    def extract_nif(text)
      # With explicit label
      labeled = text.match(/(?:NIF|CIF|DNI)\s*[:\-]?\s*([A-Z0-9]{8,9}[A-Z0-9]?)/i)
      return labeled[1].tr(".", "") if labeled

      # Spanish CIF (letter + 7 digits + letter/digit), may end with dot
      cif = text.match(/\b([A-Z]\d{7}[A-Z0-9])\.?\b/)
      return cif[1] if cif

      # Spanish NIF (8 digits + letter)
      nif = text.match(/\b(\d{8}[A-Z])\b/)
      nif&.[](1)
    end

    def extract_issuer(text)
      lines = text.split("\n").map(&:strip).reject(&:empty?)

      # Find the line containing a tax ID and use the line above it
      nif_idx = lines.index { |l| l.match?(/\b[A-Z]\d{7}[A-Z0-9]\.?\b|\b\d{8}[A-Z]\b/i) }
      if nif_idx&.positive?
        candidate = lines[nif_idx - 1].split(/\s{3,}/).first&.strip&.gsub(/[,\.]+$/, "")
        return candidate if candidate&.length&.> 2
      end

      lines.first
    end

    def extract_iva_lines(text)
      # Strategy 1: "IVA (21.00 %) sobre 43,8016 €" — O2-style
      sobre = text.match(/IVA\s*\((\d{1,2})[\.,]\d*\s*%\)\s+sobre\s+([\d\.,]+)/i)
      if sobre
        rate = sobre[1].to_i
        base = parse_amount(sobre[2])
        if base&.positive? && IVA_RATES.include?(rate)
          return [{ iva_rate: rate, base_imponible: base, iva_amount: (base * rate / 100.0).round(2) }]
        end
      end

      # Strategy 2: explicit "Base imponible" label + nearby IVA rate
      base_match    = text.match(/\bbase(?:\s+imponible)?\s*[:\-]?\s*([\d\.,]+)/i)
      iva_pct_match = text.match(/(\d{1,2})[\.,]?0*\s*%\s*(?:i\.?v\.?a\.?|iva)/i)

      if base_match && iva_pct_match
        base = parse_amount(base_match[1])
        rate = iva_pct_match[1].to_i
        if base&.positive? && IVA_RATES.include?(rate)
          return [{ iva_rate: rate, base_imponible: base, iva_amount: (base * rate / 100.0).round(2) }]
        end
      end

      # Strategy 3: amount immediately following the percentage sign
      lines = IVA_RATES.filter_map do |rate|
        match = text.match(/#{rate}[\.,]?0*\s*%[^\d]*([\d\.]+[\.,]\d{2})/i)
        next unless match

        base = parse_amount(match[1])
        next unless base&.positive?

        { iva_rate: rate, base_imponible: base, iva_amount: (base * rate / 100.0).round(2) }
      end

      lines.empty? ? inferred_line(text) : lines
    end

    def inferred_line(text)
      match = text.match(/base\s+imponible[^\d]*([\d\.]+[\.,]\d{2})/i)
      return [] unless match

      base = parse_amount(match[1])
      return [] unless base

      [{ iva_rate: 21, base_imponible: base, iva_amount: (base * 0.21).round(2) }]
    end

    def parse_amount(str)
      return nil if str.nil?

      # Spanish notation: dot as thousands separator, comma as decimal
      cleaned = if str.match?(/\.\d{3}[,]\d{2,}$/) || str.match?(/^\d{1,3}(\.\d{3})*,\d{2,}$/)
        str.gsub(".", "").gsub(",", ".")
      else
        str.gsub(",", ".")
      end

      cleaned.to_f
    end
  end
end
