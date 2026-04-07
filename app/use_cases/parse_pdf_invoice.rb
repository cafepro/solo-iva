# Orchestrates PDF extraction: tries regex first, falls back to Gemini when
# critical fields (invoice number, date, or lines) are missing.
class ParsePdfInvoice
  class ParseError < StandardError; end

  def initialize(source)
    @source = source
  end

  def call
    text   = extract_text
    result = Pdf::RegexExtractor.new(@source).extract
    result = gemini_fallback(text) if needs_fallback?(result)
    result
  rescue ParseError
    raise
  rescue => e
    raise ParseError, "Could not parse PDF: #{e.message}"
  end

  private

  def needs_fallback?(result)
    result.invoice_number.nil? || result.invoice_date.nil? || result.lines.empty?
  end

  def gemini_fallback(text)
    api_key = Rails.application.credentials.gemini_api_key
    return empty_result unless api_key.present?

    Pdf::GeminiExtractor.new(text, api_key: api_key).extract
  end

  def extract_text
    @source.rewind if @source.respond_to?(:rewind)
    reader = PDF::Reader.new(@source)
    text   = reader.pages.map(&:text).join("\n")
    @source.rewind if @source.respond_to?(:rewind)
    text
  end

  def empty_result
    PdfExtractionResult.new(invoice_number: nil, invoice_date: nil,
                            issuer_name: nil, issuer_nif: nil, lines: [])
  end
end
