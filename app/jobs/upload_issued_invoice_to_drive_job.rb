class UploadIssuedInvoiceToDriveJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(invoice_id)
    invoice = Invoice.find_by(id: invoice_id)
    return unless invoice
    return unless invoice.emitida? && invoice.confirmed?
    return if invoice.google_drive_file_id.present?
    return if invoice.invoice_lines.empty?

    user = invoice.user
    return unless user.google_drive_ready?

    year  = (invoice.invoice_date || invoice.created_at.to_date).year
    month = (invoice.invoice_date || invoice.created_at.to_date).month
    path  = user.google_drive_issued_invoice_path_prefix_segments

    client = GoogleDrive::ApiClient.new(refresh_token: user.google_drive_refresh_token)
    pdf_io = Pdf::IssuedInvoicePdf.render(invoice)
    fname  = "emitida_#{invoice.invoice_number.to_s.gsub(/[^\w.\-]+/, '_')}.pdf"

    file = client.upload_file(
      io:                   pdf_io,
      filename:             fname,
      content_type:         "application/pdf",
      path_prefix_segments: path,
      year:                 year,
      month:                month
    )

    invoice.update_columns(
      google_drive_file_id:   file.id,
      google_drive_synced_at: Time.current
    )
  end
end
