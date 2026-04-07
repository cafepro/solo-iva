# Orchestrates PDF extraction: tries regex first, falls back to Gemini if no lines found.
class ParsePdfInvoice
  class ParseError < StandardError; end

  def initialize(source)
    @source = source
  end

  def call
    result = Pdf::RegexExtractor.new(@source).extract
    result = gemini_fallback if result.lines.empty?
    result
  rescue ParseError
    raise
  rescue => e
    raise ParseError, "Could not parse PDF: #{e.message}"
  end

  private

  def gemini_fallback
    api_key = Rails.application.credentials.gemini_api_key
    return empty_result unless api_key.present?

    # Re-read text for Gemini since RegexExtractor already consumed the IO
    text = extract_text
    Pdf::GeminiExtractor.new(text, api_key: api_key).extract
  end

  def extract_text
    reader = PDF::Reader.new(@source)
    reader.pages.map(&:text).join("\n")
  end

  def empty_result
    PdfExtractionResult.new(invoice_number: nil, invoice_date: nil,
                            issuer_name: nil, issuer_nif: nil, lines: [])
  end
end
