# Parses a PDF (text + AI) or an invoice photo (vision AI) and returns PdfExtractionResult objects.
class ParseInvoiceDocument
  def initialize(source, filename: nil)
    @source   = source
    @filename = filename.presence || "document.pdf"
  end

  def call
    @source.rewind if @source.respond_to?(:rewind)
    bytes = @source.read.to_s.b
    kind  = InvoiceFileKind.from_bytes_and_filename(bytes, @filename)

    raise ParsePdfInvoice::ParseError, "Formato no reconocido. Usa PDF o imagen (JPEG, PNG o WebP)." if kind.nil?

    case kind
    when :pdf
      ParsePdfInvoice.new(StringIO.new(bytes)).call
    when :image
      ParseInvoiceImage.new(bytes, filename: @filename).call
    else
      []
    end
  rescue ParsePdfInvoice::ParseError
    raise
  rescue => e
    raise ParsePdfInvoice::ParseError, "Could not parse document: #{e.message}"
  end
end
