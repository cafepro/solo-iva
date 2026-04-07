module Pdf
  # Extracts invoice data by sending the PDF text to the Gemini API.
  # Used as a fallback when regex extraction yields no lines.
  class GeminiExtractor
    API_URL  = "https://generativelanguage.googleapis.com"
    MODEL    = "gemini-2.5-flash"
    MAX_CHARS = 3000

    def initialize(text, api_key:)
      @text    = text
      @api_key = api_key
    end

    def extract
      response = call_api
      parse_response(response)
    rescue => e
      Rails.logger.warn("GeminiExtractor failed: #{e.message}")
      empty_result
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

      PdfExtractionResult.new(
        invoice_number: json["invoice_number"],
        invoice_date:   json["invoice_date"] ? Date.parse(json["invoice_date"]) : nil,
        issuer_name:    json["issuer_name"],
        issuer_nif:     json["issuer_nif"],
        lines:          (json["lines"] || []).map(&:symbolize_keys)
      )
    end

    def prompt
      <<~PROMPT
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
        #{@text.truncate(MAX_CHARS)}
      PROMPT
    end

    def empty_result
      PdfExtractionResult.new(invoice_number: nil, invoice_date: nil,
                              issuer_name: nil, issuer_nif: nil, lines: [])
    end
  end
end
