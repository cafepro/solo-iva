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
      def chat_completion(user_prompt, temperature: 0.1)
        connection.post(
          "/openai/v1/chat/completions",
          {
            model:       @model,
            messages:    [ { role: "user", content: user_prompt } ],
            temperature: temperature
          }
        )
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
