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

    results = ParseInvoiceDocument.new(StringIO.new(file_data), filename: upload.filename).call

    return unless PdfUpload.exists?(id: pdf_upload_id)

    upload = PdfUpload.find_by(id: pdf_upload_id)
    return unless upload

    saved_count = 0

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

      if invoice.save
        saved_count += 1
      else
        Rails.logger.warn("ProcessPdfUploadJob: factura no guardada (pdf_upload_id=#{pdf_upload_id}): #{invoice.errors.full_messages.join(', ')}")
      end
    end

    upload = PdfUpload.find_by(id: pdf_upload_id)
    return unless upload

    if saved_count.zero?
      msg = if results.empty?
        "No se pudo extraer ninguna factura. Suele deberse a cuota de las APIs, a un PDF sin texto seleccionable o a una foto ilegible. Comprueba iluminación y encuadre."
      else
        "Se detectaron datos pero ninguna factura pudo guardarse (revisa duplicados o campos obligatorios)."
      end
      upload.update!(status: :failed, error_message: msg)
    else
      upload.update!(status: :done)
    end

    broadcast_update(upload)
  rescue ParsePdfInvoice::ParseError => e
    failed = PdfUpload.find_by(id: pdf_upload_id)
    if failed
      failed.update(status: :failed, error_message: e.message)
      broadcast_update(failed)
    end
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
