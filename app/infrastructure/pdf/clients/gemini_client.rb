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
        generate_content_parts([ { text: prompt } ])
      end

      # +parts+ is an array of Gemini parts, e.g. [{ text: "..." }, { inline_data: { mime_type:, data: } }]
      def generate_content_parts(parts)
        connection.post(
          "/v1beta/models/#{@model}:generateContent",
          { contents: [ { parts: parts } ] },
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
