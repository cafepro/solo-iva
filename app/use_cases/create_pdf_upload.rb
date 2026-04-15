class CreatePdfUpload
  def initialize(user:, file:, invoice_type: :recibida)
    @user         = user
    @file         = file
    @invoice_type = invoice_type.to_sym
  end

  def call
    unless %i[emitida recibida].include?(@invoice_type)
      raise ArgumentError, "Tipo de factura no válido para la subida."
    end

    unless InvoiceFileKind.supported_upload?(@file)
      raise ArgumentError,
            "Formato no admitido. Sube un PDF o una foto (JPEG, PNG o WebP). Las fotos HEIC deben convertirse a JPG."
    end

    @file.rewind if @file.respond_to?(:rewind)

    upload = @user.pdf_uploads.create!(
      filename:     @file.original_filename,
      file_data:    @file.read,
      status:       :pending,
      invoice_type: @invoice_type
    )
    ProcessPdfUploadJob.perform_later(upload.id)
    upload
  end
end
