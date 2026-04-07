require "pdf-reader"

module Pdf
  # Extracts invoice data from a PDF using regex heuristics.
  # Returns a PdfExtractionResult. Falls back to an empty result if nothing is found.
  class RegexExtractor
    IVA_RATES = [21, 10, 5, 4, 0].freeze

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
      lines = text.split("\n").map(&:strip).reject(&:empty?)
      nif_idx = lines.index { |l| l.match?(/NIF|CIF|DNI/i) }
      nif_idx&.positive? ? lines[nif_idx - 1] : lines.first
    end

    def extract_iva_lines(text)
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

      # Spanish notation uses dots as thousands separators and commas as decimals
      cleaned = if str.match?(/\.\d{3}[,]\d{2}$/) || str.match?(/^\d{1,3}(\.\d{3})*,\d{2}$/)
        str.gsub(".", "").gsub(",", ".")
      else
        str.gsub(",", "")
      end

      cleaned.to_f
    end
  end
end
