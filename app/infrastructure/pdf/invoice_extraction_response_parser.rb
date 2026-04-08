module Pdf
  # Parses raw model output (JSON string, optionally wrapped in markdown fences) into PdfExtractionResult list.
  class InvoiceExtractionResponseParser
    def self.parse(raw)
      new(raw).parse
    end

    def initialize(raw)
      @raw = raw
    end

    def parse
      return [] if @raw.blank?

      json = JSON.parse(@raw.to_s.gsub(/```json\n?|\n?```/, ""))
      invoices = json["invoices"] || []
      invoices.filter_map { |inv| build_result(inv) }
    rescue JSON::ParserError
      []
    end

    private

    def build_result(inv)
      PdfExtractionResult.new(
        invoice_number: inv["invoice_number"],
        invoice_date:   parse_model_date(inv["invoice_date"]),
        issuer_name:    inv["issuer_name"],
        issuer_nif:     inv["issuer_nif"],
        lines:          (inv["lines"] || []).map(&:symbolize_keys)
      )
    end

    def parse_model_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError, Date::Error
      nil
    end
  end
end
