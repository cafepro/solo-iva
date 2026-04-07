module Pdf
  # Extracts invoice data by sending the PDF text to the Gemini API.
  # Returns an array of PdfExtractionResult — a single PDF may contain
  # multiple invoices (e.g. combined utility bills).
  class GeminiExtractor
    API_URL   = "https://generativelanguage.googleapis.com"
    MODEL     = "gemini-2.5-flash"
    MAX_CHARS = 12000

    def initialize(text, api_key:)
      @text    = text
      @api_key = api_key
    end

    def extract
      response = call_api
      parse_response(response)
    rescue => e
      Rails.logger.warn("GeminiExtractor failed: #{e.message}")
      []
    end

    private

    def call_api
      conn = Faraday.new(API_URL) do |f|
        f.request :json
        f.response :json
      end

      conn.post(
        "/v1beta/models/#{MODEL}:generateContent",
        { contents: [{ parts: [{ text: prompt }] }] },
        { "x-goog-api-key" => @api_key }
      )
    end

    def parse_response(response)
      raw  = response.body.dig("candidates", 0, "content", "parts", 0, "text")
      json = JSON.parse(raw&.gsub(/```json\n?|\n?```/, "") || "{}")

      invoices = json["invoices"] || []
      invoices.map { |inv| build_result(inv) }
    end

    def build_result(inv)
      PdfExtractionResult.new(
        invoice_number: inv["invoice_number"],
        invoice_date:   inv["invoice_date"] ? Date.parse(inv["invoice_date"]) : nil,
        issuer_name:    inv["issuer_name"],
        issuer_nif:     inv["issuer_nif"],
        lines:          (inv["lines"] || []).map(&:symbolize_keys)
      )
    end

    def prompt
      <<~PROMPT
        Extract all invoices found in the following Spanish invoice text and return them as JSON.
        A single PDF may contain more than one invoice (e.g. a combined water + waste bill).
        Return ONLY the raw JSON object — no explanations, no markdown, no code blocks.

        Rules per invoice:
        - "invoice_number": the unique invoice identifier (e.g. "1261042548", "F-2026-001").
          Must contain at least one digit and be longer than 3 characters. Never use a date or generic word.
        - "invoice_date": invoice issue date in YYYY-MM-DD format, or null.
        - "issuer_name": legal name of the company that issued this specific invoice (the supplier/vendor),
          NOT the recipient or customer.
        - "issuer_nif": Spanish tax ID (NIF/CIF) of the issuer, or null if not present.
        - "lines": array of VAT lines for this invoice, each with:
            - "iva_rate": VAT rate as an integer (0, 4, 10 or 21)
            - "base_imponible": taxable base amount in euros as a decimal number
            - "iva_amount": VAT amount in euros as a decimal number
          Merge lines with the same VAT rate into one. Exclude lines where base_imponible is 0.

        Expected JSON format (always return an "invoices" array, even if there is only one):
        {
          "invoices": [
            {
              "invoice_number": "string or null",
              "invoice_date": "YYYY-MM-DD or null",
              "issuer_name": "string or null",
              "issuer_nif": "string or null",
              "lines": [
                { "iva_rate": 21, "base_imponible": 100.00, "iva_amount": 21.00 }
              ]
            }
          ]
        }

        Invoice text:
        #{@text.truncate(MAX_CHARS)}
      PROMPT
    end
  end
end
