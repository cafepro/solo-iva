module Pdf
  # Sends invoice text to Groq (OpenAI-compatible API) and returns PdfExtractionResult objects.
  class GroqExtractor
    MODEL          = "llama-3.3-70b-versatile"
    FALLBACK_MODEL = "llama-3.1-8b-instant" # separate TPD limits; weaker but useful when 70B quota is exhausted

    # Groq/Llama often prepends a faux "summary" of the bill; that breaks naive JSON.parse and can exhaust tokens.
    SYSTEM_PROMPT = <<~TEXT.squish
      You extract structured data from Spanish invoice text.
      Your entire reply must be a single JSON object with an "invoices" array, exactly as requested in the user message.
      Do not repeat, summarize, or re-transcribe the source text — output only valid JSON, no markdown fences.
    TEXT

    def initialize(text, user: nil, client: nil)
      @text            = text
      @user            = user
      @client_override = client
    end

    def extract
      if @client_override
        return run_with_client(@client_override)
      end

      key = Pdf::AiCredentials.groq_api_key_for(@user)
      return [] if key.blank?

      [ MODEL, FALLBACK_MODEL ].uniq.each do |model_name|
        client = Clients::GroqClient.new(api_key: key, model: model_name)
        results = run_with_client(client)
        return results if results.any?
      end

      []
    rescue Faraday::Error => e
      Rails.logger.warn("GroqExtractor failed: #{e.message}")
      []
    rescue => e
      Rails.logger.warn("GroqExtractor failed: #{e.message}")
      []
    end

    private

    attr_reader :text

    def run_with_client(client)
      response = client.chat_completion(
        InvoiceExtractionPrompt.build(text),
        max_tokens:    8192,
        system_prompt: SYSTEM_PROMPT
      )
      unless response.success?
        err = response.body.is_a?(Hash) ? response.body.dig("error", "message") : nil
        Rails.logger.warn("GroqExtractor HTTP #{response.status}: #{err || response.body}")
        return []
      end

      parse_response(response)
    end

    def parse_response(response)
      body = response.body
      if body.is_a?(Hash) && body["error"].present?
        Rails.logger.warn("GroqExtractor API error: #{body['error']}")
        return []
      end

      raw = body.dig("choices", 0, "message", "content")
      return [] if raw.blank?

      results = InvoiceExtractionResponseParser.parse(raw)
      if results.empty?
        Rails.logger.warn("GroqExtractor invalid or empty JSON from model")
      end
      results
    end
  end
end
