class ParsePdfInvoice
  class ParseError < StandardError; end

  def initialize(source)
    @source = source
  end

  # Returns an array of PdfExtractionResult (one per invoice found in the PDF).
  # Tries Gemini, then Groq when configured; if both yield nothing, falls back to heuristics.
  def call
    text = extract_text

    results = Pdf::GeminiExtractor.new(text).extract
    results = Pdf::GroqExtractor.new(text).extract if results.empty?

    results = Pdf::HeuristicInvoiceExtractor.new(text).extract if results.empty?

    results
  rescue ParseError
    raise
  rescue => e
    raise ParseError, "Could not parse PDF: #{e.message}"
  end

  private

  attr_reader :source

  def extract_text
    source.rewind if source.respond_to?(:rewind)
    PDF::Reader.new(source).pages.map(&:text).join("\n")
  end
end
