class CreatePdfUpload
  def initialize(user:, file:)
    @user = user
    @file = file
  end

  def call
    unless InvoiceFileKind.supported_upload?(@file)
      raise ArgumentError,
            "Formato no admitido. Sube un PDF o una foto (JPEG, PNG o WebP). Las fotos HEIC deben convertirse a JPG."
    end

    @file.rewind if @file.respond_to?(:rewind)

    upload = @user.pdf_uploads.create!(
      filename:  @file.original_filename,
      file_data: @file.read,
      status:    :pending
    )
    ProcessPdfUploadJob.perform_later(upload.id)
    upload
  end
end
