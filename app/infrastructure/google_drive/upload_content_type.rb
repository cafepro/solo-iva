module GoogleDrive
  module UploadContentType
    def self.for_filename(filename)
      ext = File.extname(filename.to_s).downcase
      case ext
      when ".pdf"          then "application/pdf"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".png"          then "image/png"
      when ".webp"         then "image/webp"
      else
        "application/octet-stream"
      end
    end
  end
end
