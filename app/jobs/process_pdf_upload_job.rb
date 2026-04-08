class ProcessPdfUploadJob < ApplicationJob
  queue_as :default

  def perform(pdf_upload_id)
    upload = PdfUpload.find(pdf_upload_id)
    upload.update!(status: :processing)

    results = ParsePdfInvoice.new(StringIO.new(upload.file_data)).call

    results.each do |result|
      next if result.invoice_number.blank? || result.lines.empty?

      invoice = upload.user.invoices.build(
        status:         :pending,
        invoice_type:   :recibida,
        invoice_number: result.invoice_number,
        invoice_date:   result.invoice_date,
        issuer_name:    result.issuer_name,
        issuer_nif:     result.issuer_nif
      )

      result.lines.each do |line|
        invoice.invoice_lines.build(
          iva_rate:       line[:iva_rate],
          base_imponible: line[:base_imponible].to_d.round(2)
        )
      end

      invoice.save
    end

    upload.update!(status: :done)

    broadcast_update(upload)
  rescue => e
    upload&.update(status: :failed, error_message: e.message)
    broadcast_update(upload) if upload
    raise
  end

  private

  def broadcast_update(upload)
    pending_count = upload.user.invoices.pending_review.count

    Turbo::StreamsChannel.broadcast_replace_to(
      "pdf_uploads_#{upload.user_id}",
      target:  "pdf_upload_#{upload.id}",
      partial: "invoices/pdf_upload_row",
      locals:  { upload: upload }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "pending_badge_#{upload.user_id}",
      target:  "pending_badge",
      partial: "layouts/pending_badge",
      locals:  { count: pending_count }
    )

    Turbo::StreamsChannel.broadcast_prepend_to(
      "pending_invoices_#{upload.user_id}",
      target:  "pending_invoices",
      partial: "invoices/pending_invoice_cards",
      locals:  { invoices: upload.user.invoices.pending_review.where(created_at: 1.second.ago..) }
    )
  end
end
