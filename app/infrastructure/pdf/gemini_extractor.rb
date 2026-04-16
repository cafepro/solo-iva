module Pdf
  # Sends invoice text to Gemini and returns PdfExtractionResult objects.
  class GeminiExtractor
    # Primary model first; on 429/503 or empty JSON, try lite (separate quota pool on free tier).
    MODEL_CHAIN = %w[gemini-2.5-flash gemini-2.5-flash-lite].freeze

    def initialize(text, user: nil, client: nil)
      @text            = text
      @user            = user
      @client_override = client
    end

    def extract
      if @client_override
        return run_with_client(@client_override)
      end

      key = Pdf::AiCredentials.gemini_api_key_for(@user)
      return [] if key.blank?

      MODEL_CHAIN.each do |model|
        client = Clients::GeminiClient.new(api_key: key, model: model)
        results = run_with_client(client)
        return results if results.any?
      end

      []
    rescue Faraday::Error => e
      Rails.logger.warn("GeminiExtractor failed: #{e.message}")
      []
    rescue => e
      Rails.logger.warn("GeminiExtractor failed: #{e.message}")
      []
    end

    private

    attr_reader :text

    def run_with_client(client)
      response = client.generate_content(InvoiceExtractionPrompt.build(text))
      unless response.success?
        err = response.body.is_a?(Hash) ? response.body.dig("error", "message") : nil
        Rails.logger.warn("GeminiExtractor HTTP #{response.status}: #{err || response.body}")
        return []
      end

      parse_response(response)
    end

    def parse_response(response)
      body = response.body
      if body.is_a?(Hash) && body["error"].present?
        Rails.logger.warn("GeminiExtractor API error: #{body['error']}")
        return []
      end

      raw = body.dig("candidates", 0, "content", "parts", 0, "text")
      return [] if raw.blank?

      results = InvoiceExtractionResponseParser.parse(raw)
      if results.empty?
        Rails.logger.warn("GeminiExtractor invalid or empty JSON from model")
      end
      results
    end
  end
end
