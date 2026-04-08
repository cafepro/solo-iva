# Runs vision-only extraction (Gemini then Groq) on a raster image of an invoice.
class ParseInvoiceImage
  def initialize(image_bytes, filename:)
    @bytes    = image_bytes.to_s.b
    @filename = filename.to_s
  end

  def call
    mime = InvoiceFileKind.vision_mime_for(@bytes, @filename)
    unless mime.present? && InvoiceFileKind::SUPPORTED_IMAGE_MIMES.include?(mime)
      Rails.logger.warn("ParseInvoiceImage: unsupported or unknown MIME for #{@filename.inspect}")
      return []
    end

    results = Pdf::GeminiVisionExtractor.new(@bytes, mime_type: mime).extract
    results = Pdf::GroqVisionExtractor.new(@bytes, mime_type: mime).extract if results.empty?
    results
  end
end
