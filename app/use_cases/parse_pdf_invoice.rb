class ParsePdfInvoice
  class ParseError < StandardError; end

  def initialize(source)
    @source = source
  end

  def call
    api_key = Rails.application.credentials.gemini_api_key
    raise ParseError, "Gemini API key not configured" unless api_key.present?

    Pdf::GeminiExtractor.new(extract_text, api_key: api_key).extract
  rescue ParseError
    raise
  rescue => e
    raise ParseError, "Could not parse PDF: #{e.message}"
  end

  private

  def extract_text
    @source.rewind if @source.respond_to?(:rewind)
    PDF::Reader.new(@source).pages.map(&:text).join("\n")
  end
end
