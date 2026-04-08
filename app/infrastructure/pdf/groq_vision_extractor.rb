module Pdf
  # Multimodal Groq (Llama 4 Scout): invoice photos when Gemini is unavailable or empty.
  class GroqVisionExtractor
    MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

    def initialize(image_bytes, mime_type:, client: nil)
      @bytes           = image_bytes.to_s.b
      @mime_type       = mime_type
      @client_override = client
    end

    def extract
      parts = build_user_content

      if @client_override
        return run_with_client(@client_override, parts)
      end

      key = groq_api_key
      return [] if key.blank?

      client = Clients::GroqClient.new(api_key: key, model: MODEL)
      run_with_client(client, parts)
    rescue Faraday::Error => e
      Rails.logger.warn("GroqVisionExtractor failed: #{e.message}")
      []
    rescue => e
      Rails.logger.warn("GroqVisionExtractor failed: #{e.message}")
      []
    end

    private

    def build_user_content
      b64      = Base64.strict_encode64(@bytes)
      data_uri = "data:#{@mime_type};base64,#{b64}"
      [
        { type: "text", text: InvoiceExtractionPrompt.for_vision },
        { type: "image_url", image_url: { url: data_uri } }
      ]
    end

    def groq_api_key
      k = Rails.application.credentials.groq_api_key
      k.presence || ENV["GROQ_API_KEY"]
    rescue NoMethodError
      ENV["GROQ_API_KEY"]
    end

    def run_with_client(client, user_content)
      messages = [
        { role: "system", content: GroqExtractor::SYSTEM_PROMPT },
        { role: "user", content: user_content }
      ]

      response = client.chat_completion_messages(
        messages,
        max_tokens:    8192,
        temperature:   0.1
      )

      unless response.success?
        err = response.body.is_a?(Hash) ? response.body.dig("error", "message") : nil
        Rails.logger.warn("GroqVisionExtractor HTTP #{response.status}: #{err || response.body}")
        return []
      end

      parse_response(response)
    end

    def parse_response(response)
      body = response.body
      if body.is_a?(Hash) && body["error"].present?
        Rails.logger.warn("GroqVisionExtractor API error: #{body['error']}")
        return []
      end

      raw = body.dig("choices", 0, "message", "content")
      return [] if raw.blank?

      results = InvoiceExtractionResponseParser.parse(raw)
      Rails.logger.warn("GroqVisionExtractor invalid or empty JSON from model") if results.empty?
      results
    end
  end
end
