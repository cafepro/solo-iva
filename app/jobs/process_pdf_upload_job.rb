class ProcessPdfUploadJob < ApplicationJob
  # Dedicated queue: single Solid Queue worker thread (see config/queue.yml) so we do not
  # hammer external APIs in parallel. limits_concurrency also avoids overlap if more
  # processes run or the concurrency lease expires.
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

      if received_invoice_number_taken?(user, result.invoice_number)
        Rails.logger.info(
          "ProcessPdfUploadJob: skipping duplicate received invoice_number=#{result.invoice_number.inspect} (pdf_upload_id=#{pdf_upload_id})"
        )
        next
      end

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
        Rails.logger.warn("ProcessPdfUploadJob: invoice not saved (pdf_upload_id=#{pdf_upload_id}): #{invoice.errors.full_messages.join(', ')}")
      end
    end

    upload = PdfUpload.find_by(id: pdf_upload_id)
    return unless upload

    if saved_count.zero?
      extractable = results.select { |r| r.invoice_number.present? && r.lines.any? }

      msg = if results.empty?
        "No se pudo extraer ninguna factura. Suele deberse a cuota de las APIs, a un PDF sin texto seleccionable o a una foto ilegible. Comprueba iluminación y encuadre."
      elsif extractable.empty?
        "Se detectaron datos pero ninguna factura pudo guardarse (faltan número o líneas de IVA)."
      elsif extractable.all? { |r| received_invoice_number_taken?(user, r.invoice_number) }
        "Las facturas detectadas ya estaban registradas o duplicadas (mismo número de factura recibida)."
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

  # True if this user already has a received invoice (:recibida) with this number (confirmed or pending).
  def received_invoice_number_taken?(user, invoice_number)
    user.invoices.for_accounting.exists?(invoice_type: :recibida, invoice_number: invoice_number) ||
      user.invoices.pending_review.exists?(invoice_type: :recibida, invoice_number: invoice_number)
  end

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
