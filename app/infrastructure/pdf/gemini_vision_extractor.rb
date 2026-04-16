module Pdf
  # Multimodal Gemini: reads invoice photos/scans and returns PdfExtractionResult objects.
  class GeminiVisionExtractor
    MODEL_CHAIN = GeminiExtractor::MODEL_CHAIN

    def initialize(image_bytes, mime_type:, user: nil, client: nil)
      @bytes           = image_bytes.to_s.b
      @mime_type       = mime_type
      @user            = user
      @client_override = client
    end

    def extract
      parts = build_parts

      if @client_override
        return run_with_client(@client_override, parts)
      end

      key = Pdf::AiCredentials.gemini_api_key_for(@user)
      return [] if key.blank?

      MODEL_CHAIN.each do |model|
        client = Clients::GeminiClient.new(api_key: key, model: model)
        results = run_with_client(client, parts)
        return results if results.any?
      end

      []
    rescue Faraday::Error => e
      Rails.logger.warn("GeminiVisionExtractor failed: #{e.message}")
      []
    rescue => e
      Rails.logger.warn("GeminiVisionExtractor failed: #{e.message}")
      []
    end

    private

    def build_parts
      b64 = Base64.strict_encode64(@bytes)
      [
        { text: InvoiceExtractionPrompt.for_vision },
        { inline_data: { mime_type: @mime_type, data: b64 } }
      ]
    end

    def run_with_client(client, parts)
      response = client.generate_content_parts(parts)
      unless response.success?
        err = response.body.is_a?(Hash) ? response.body.dig("error", "message") : nil
        Rails.logger.warn("GeminiVisionExtractor HTTP #{response.status}: #{err || response.body}")
        return []
      end

      parse_response(response)
    end

    def parse_response(response)
      body = response.body
      if body.is_a?(Hash) && body["error"].present?
        Rails.logger.warn("GeminiVisionExtractor API error: #{body['error']}")
        return []
      end

      raw = body.dig("candidates", 0, "content", "parts", 0, "text")
      return [] if raw.blank?

      results = InvoiceExtractionResponseParser.parse(raw)
      Rails.logger.warn("GeminiVisionExtractor invalid or empty JSON from model") if results.empty?
      results
    end
  end
end
