class ProcessPdfUploadJob < ApplicationJob
  # Cola dedicada: un solo hilo en Solid Queue (ver config/queue.yml) para no lanzar
  # varios PDFs a la vez. Además, limits_concurrency evita solaparse si hubiera más
  # procesos o si el control de concurrencia caduca tras `duration`.
  queue_as :pdf_import

  limits_concurrency key: ->(_pdf_upload_id) { "gemini_pdf_invoice_extract" },
                     to: 1,
                     duration: 2.hours,
                     group: "GeminiPdfInvoiceImport"

  def perform(pdf_upload_id)
    upload = PdfUpload.find_by(id: pdf_upload_id)
    return unless upload

    file_data = upload.file_data
    user      = upload.user

    upload.update!(status: :processing)

    return unless PdfUpload.exists?(id: pdf_upload_id)

    results = ParsePdfInvoice.new(StringIO.new(file_data)).call

    return unless PdfUpload.exists?(id: pdf_upload_id)

    upload = PdfUpload.find_by(id: pdf_upload_id)
    return unless upload

    results.each do |result|
      next if result.invoice_number.blank? || result.lines.empty?

      invoice = user.invoices.build(
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

    upload = PdfUpload.find_by(id: pdf_upload_id)
    return unless upload

    upload.update!(status: :done)

    broadcast_update(upload)
  rescue => e
    failed = PdfUpload.find_by(id: pdf_upload_id)
    if failed
      failed.update(status: :failed, error_message: e.message)
      broadcast_update(failed)
    end
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

    pending = upload.user.invoices.pending_review.includes(:invoice_lines).order(:created_at)
    Turbo::StreamsChannel.broadcast_replace_to(
      "pending_invoices_#{upload.user_id}",
      target:  "pending_invoices",
      partial: "invoices/pending_invoices_panel",
      locals:  { invoices: pending }
    )
  end
end
