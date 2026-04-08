class ParsePdfInvoice
  class ParseError < StandardError; end

  def initialize(source)
    @source = source
  end

  # Returns an array of PdfExtractionResult (one per invoice found in the PDF).
  # Uses Gemini when configured; if that yields nothing (quota, empty model output, etc.),
  # falls back to heuristics on the extracted text.
  def call
    text = extract_text

    results = []
    api_key = Rails.application.credentials.gemini_api_key
    if api_key.present?
      results = Pdf::GeminiExtractor.new(text, api_key: api_key).extract
    end

    results = Pdf::HeuristicInvoiceExtractor.new(text).extract if results.empty?

    results
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
