module Pdf
  # Fallback when Gemini is unavailable, returns empty, or omits an invoice.
  # Targets common Spanish PDF text layouts (Serenos-style utilities, etc.).
  class HeuristicInvoiceExtractor
    def initialize(text)
      @text = text.to_s
    end

    def extract
      invoice_number = @text.match(/N[ºª°]?\s*Factura:\s*([A-Za-z0-9\-]+)/i)&.[](1)&.strip
      date_raw       = match_invoice_date_raw
      base_raw       = @text.match(/Base\s+([\d.,]+)\s*€/i)&.[](1)
      iva_match      = match_iva_line

      return [] unless invoice_number.present? && date_raw.present? && base_raw.present? && iva_match

      iva_rate   = iva_match[1].to_i
      iva_amount = parse_decimal(iva_match[2])
      base       = parse_decimal(base_raw)

      return [] unless [ 0, 4, 10, 21 ].include?(iva_rate)
      return [] if base.nil? || base <= 0

      invoice_date = parse_spanish_date(date_raw)
      return [] unless invoice_date

      quota = iva_amount || (base * iva_rate / 100).round(2)

      [
        PdfExtractionResult.new(
          invoice_number: invoice_number,
          invoice_date:   invoice_date,
          issuer_name:    extract_issuer_name,
          issuer_nif:     extract_nif,
          lines:          [ { iva_rate: iva_rate, base_imponible: base.to_f, iva_amount: quota.to_f } ]
        )
      ]
    end

    private

    def match_invoice_date_raw
      [
        /Fecha de factura:\s*(\d{1,2}\/\d{1,2}\/\d{2,4})/i,
        /Fecha de emisión:\s*(\d{1,2}\/\d{1,2}\/\d{2,4})/i,
        /Fecha:\s*(\d{1,2}\/\d{1,2}\/\d{2,4})/i
      ].each do |pattern|
        m = @text.match(pattern)
        return m[1] if m
      end
      nil
    end

    def match_iva_line
      @text.match(/(\d{1,2})%\s*I\.V\.A\.\s+([\d.,]+)\s*€/i) ||
        @text.match(/(\d{1,2})%\s*I\.?\s*V\.?\s*A\.?\s+([\d.,]+)\s*€/i)
    end

    def parse_decimal(str)
      BigDecimal(str.to_s.tr(".", "").tr(",", "."))
    rescue ArgumentError
      nil
    end

    def parse_spanish_date(str)
      parts = str.split("/").map(&:to_i)
      return nil if parts.size != 3

      d, m, y = parts
      y += 2000 if y < 100
      Date.new(y, m, d)
    rescue ArgumentError, Date::Error
      nil
    end

    def extract_issuer_name
      first = @text.lines.first&.strip
      return nil if first.blank?

      first.split(/\s{2,}/).first&.sub(/,\s*\z/, "")&.strip
    end

    def extract_nif
      @text.match(/\b([A-HJNPQRSUVW]\d{7}[\dA-J]|\d{8}[A-Z])\b/i)&.[](1)&.upcase
    end
  end
end
