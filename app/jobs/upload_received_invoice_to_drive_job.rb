class UploadReceivedInvoiceToDriveJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(invoice_id)
    invoice = Invoice.find_by(id: invoice_id)
    return unless invoice
    return unless invoice.recibida? && invoice.confirmed?
    return if invoice.google_drive_file_id.present?
    return if invoice.invoice_lines.empty?

    user = invoice.user
    return unless user.google_drive_ready?

    year  = (invoice.invoice_date || invoice.created_at.to_date).year
    month = (invoice.invoice_date || invoice.created_at.to_date).month
    path  = user.google_drive_received_invoice_path_prefix_segments

    client = GoogleDrive::ApiClient.new(refresh_token: user.google_drive_refresh_token)

    file = if invoice_has_source_file?(invoice)
      upload_stored_original_to_drive(client, invoice, path, year, month)
    elsif invoice.pdf_upload&.file_data.present?
      upload_original_to_drive(client, invoice, path, year, month)
    else
      upload_summary_pdf_to_drive(client, invoice, path, year, month)
    end

    invoice.update_columns(
      google_drive_file_id:   file.id,
      google_drive_synced_at: Time.current
    )
  end

  private

  def invoice_has_source_file?(invoice)
    invoice.source_filename.present? &&
      invoice.source_file_data.present? &&
      invoice.source_file_data.to_s.bytesize.positive?
  end

  def upload_stored_original_to_drive(client, invoice, path, year, month)
    io = StringIO.new(invoice.source_file_data.to_s.b)
    fname = original_drive_filename(invoice.source_filename, invoice.invoice_number)
    ct    = GoogleDrive::UploadContentType.for_filename(invoice.source_filename)

    client.upload_file(
      io:                   io,
      filename:             fname,
      content_type:         ct,
      path_prefix_segments: path,
      year:                 year,
      month:                month
    )
  end

  def upload_original_to_drive(client, invoice, path, year, month)
    upload = invoice.pdf_upload
    io     = StringIO.new(upload.file_data.to_s.b)
    fname  = original_drive_filename(upload.filename, invoice.invoice_number)
    ct     = GoogleDrive::UploadContentType.for_filename(upload.filename)

    client.upload_file(
      io:                   io,
      filename:             fname,
      content_type:         ct,
      path_prefix_segments: path,
      year:                 year,
      month:                month
    )
  end

  def upload_summary_pdf_to_drive(client, invoice, path, year, month)
    pdf_io = GoogleDrive::ReceivedInvoicePdf.render(invoice)
    client.upload_file(
      io:                   pdf_io,
      filename:             "factura_recibida_#{invoice.invoice_number}.pdf",
      content_type:         "application/pdf",
      path_prefix_segments: path,
      year:                 year,
      month:                month
    )
  end

  def original_drive_filename(upload_filename, invoice_number)
    ext  = File.extname(upload_filename.to_s)
    base = File.basename(upload_filename.to_s, ".*")
    base = base.gsub(/[^\w.\-]+/, "_")
    ext  = ext.presence || ".bin"
    "#{base}_#{invoice_number.to_s.gsub(/[^\w.\-]+/, "_")}#{ext}"
  end
end
