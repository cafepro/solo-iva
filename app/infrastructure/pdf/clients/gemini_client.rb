module Pdf
  module Clients
    # HTTP client for Google Generative Language API (Gemini).
    class GeminiClient
      API_URL = "https://generativelanguage.googleapis.com"

      def initialize(api_key:, model: "gemini-2.5-flash")
        @api_key = api_key
        @model   = model
      end

      # @return [Faraday::Response]
      def generate_content(prompt)
        connection.post(
          "/v1beta/models/#{@model}:generateContent",
          { contents: [ { parts: [ { text: prompt } ] } ] },
          { "x-goog-api-key" => @api_key }
        )
      end

      private

      def connection
        @connection ||= Faraday.new(API_URL) do |f|
          f.request :json
          f.response :json
        end
      end
    end
  end
end
