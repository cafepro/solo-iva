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

      blob = extract_json_blob(@raw)
      return [] if blob.blank?

      json = JSON.parse(blob)
      invoices = json["invoices"] || []
      invoices.filter_map { |inv| build_result(inv) }
    rescue JSON::ParserError
      []
    end

    private

    # Models (e.g. Groq/Llama) often prepend analysis before the JSON object.
    # Gemini usually returns clean JSON; this path handles both.
    def extract_json_blob(raw)
      s = raw.to_s.gsub(/```json\n?|\n?```/, "").strip
      return nil if s.empty?

      begin
        JSON.parse(s)
        return s
      rescue JSON::ParserError
        # fall through
      end

      i = s.index("{")
      return nil unless i

      depth = 0
      (i...s.length).each do |j|
        case s[j]
        when "{"
          depth += 1
        when "}"
          depth -= 1
          return s[i..j] if depth.zero?
        end
      end

      nil
    end

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
