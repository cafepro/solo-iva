module Pdf
  module Clients
    # OpenAI-compatible chat completions API on GroqCloud.
    class GroqClient
      BASE_URL = "https://api.groq.com"

      def initialize(api_key:, model:)
        @api_key = api_key
        @model   = model
      end

      # @return [Faraday::Response]
      # +max_tokens+ reduces truncation when several invoices are returned as JSON.
      # Optional +system_prompt+ keeps the model from echoing the source text before the JSON (Groq/Llama quirk).
      def chat_completion(user_prompt, temperature: 0.1, max_tokens: 8192, system_prompt: nil, response_format: nil)
        messages = []
        messages << { role: "system", content: system_prompt } if system_prompt.present?
        messages << { role: "user", content: user_prompt }

        body = {
          model:       @model,
          messages:    messages,
          temperature: temperature,
          max_tokens:  max_tokens
        }
        body[:response_format] = response_format if response_format

        connection.post("/openai/v1/chat/completions", body)
      end

      private

      def connection
        @connection ||= Faraday.new(BASE_URL) do |f|
          f.request :json
          f.response :json
          f.headers["Authorization"] = "Bearer #{@api_key}"
        end
      end
    end
  end
end
