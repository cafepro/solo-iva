# Extracts invoice data from a PDF using Gemini as the primary strategy.
# The regex extractor is kept as a fast pre-check: if it already finds both
# the invoice number and IVA lines we skip the API call. Otherwise Gemini
# handles the full extraction.
class ParsePdfInvoice
  class ParseError < StandardError; end

  def initialize(source)
    @source = source
  end

  def call
    text   = extract_text
    result = Pdf::RegexExtractor.new(@source).extract

    result = gemini_extraction(text) if needs_gemini?(result)
    result
  rescue ParseError
    raise
  rescue => e
    raise ParseError, "Could not parse PDF: #{e.message}"
  end

  private

  def needs_gemini?(result)
    result.lines.empty? || !plausible_invoice_number?(result.invoice_number)
  end

  # A plausible invoice number has at least one digit and is longer than 3 chars.
  def plausible_invoice_number?(number)
    return false if number.nil?
    number.length > 3 && number.match?(/\d/)
  end

  def gemini_extraction(text)
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
