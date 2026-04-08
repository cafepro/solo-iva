class CreatePdfUpload
  def initialize(user:, file:)
    @user = user
    @file = file
  end

  def call
    upload = @user.pdf_uploads.create!(
      filename:  @file.original_filename,
      file_data: @file.read,
      status:    :pending
    )
    ProcessPdfUploadJob.perform_later(upload.id)
    upload
  end
end
