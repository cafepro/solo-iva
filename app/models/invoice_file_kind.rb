# Detects whether an uploaded file is a PDF or a raster image we can send to vision APIs.
class InvoiceFileKind
  PDF_MAGIC = "%PDF"

  SUPPORTED_IMAGE_MIMES = %w[image/jpeg image/png image/webp].freeze

  PNG_MAGIC  = "\x89PNG\r\n\x1a\n".b
  JPEG_MAGIC = "\xFF\xD8\xFF".b

  class << self
    # @return [:pdf, :image, nil]
    def from_bytes_and_filename(bytes, filename)
      b = bytes.to_s.b
      return :pdf if b.start_with?(PDF_MAGIC)
      return :image if raster_magic?(b)

      ext = File.extname(filename.to_s).downcase
      return :image if %w[.jpg .jpeg .png .webp].include?(ext) && b.bytesize >= 32

      nil
    end

    def from_upload(file)
      file.rewind if file.respond_to?(:rewind)
      bytes = file.read
      file.rewind if file.respond_to?(:rewind)
      from_bytes_and_filename(bytes, file.original_filename)
    end

    def supported_upload?(file)
      from_upload(file).present?
    end

    # MIME to pass to Gemini/Groq inline payloads (nil if unknown / not supported).
    def vision_mime_for(bytes, filename)
      b = bytes.to_s.b
      mime = mime_from_magic(b)
      return mime if mime.present?

      ext = File.extname(filename.to_s).downcase
      case ext
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".png"         then "image/png"
      when ".webp"        then "image/webp"
      else
        nil
      end
    end

    private

    def raster_magic?(b)
      return true if b.start_with?(PNG_MAGIC)
      return true if b.start_with?(JPEG_MAGIC)
      return true if webp?(b)

      false
    end

    def webp?(b)
      return false if b.bytesize < 12

      b[0, 4] == "RIFF".b && b[8, 4] == "WEBP".b
    end

    def mime_from_magic(b)
      return "image/png"  if b.start_with?(PNG_MAGIC)
      return "image/jpeg" if b.start_with?(JPEG_MAGIC)
      return "image/webp" if webp?(b)

      nil
    end
  end
end
