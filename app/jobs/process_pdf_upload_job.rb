class ProcessPdfUploadJob < ApplicationJob
  # Dedicated queue: single Solid Queue worker thread (see config/queue.yml) so we do not
  # hammer external APIs in parallel. limits_concurrency also avoids overlap if more
  # processes run or the concurrency lease expires.
  queue_as :pdf_import

  limits_concurrency key: ->(_pdf_upload_id) { "gemini_pdf_invoice_extract" },
                     to:  1,
                     duration: 2.hours,
                     group: "GeminiPdfInvoiceImport"

  def perform(pdf_upload_id)
    upload = PdfUpload.find_by(id: pdf_upload_id)
    return unless upload

    file_data = upload.file_data
    user      = upload.user

    upload.update!(status: :processing)

    return unless PdfUpload.exists?(id: pdf_upload_id)

    results = ParseInvoiceDocument.new(StringIO.new(file_data), filename: upload.filename, user: user).call

    return unless PdfUpload.exists?(id: pdf_upload_id)

    upload = PdfUpload.find_by(id: pdf_upload_id)
    return unless upload

    saved_count = 0

    results.each do |result|
      next if result.invoice_number.blank? || result.lines.empty?

      if invoice_number_taken?(user, result.invoice_number, upload.invoice_type)
        Rails.logger.info(
          "ProcessPdfUploadJob: skipping duplicate invoice_number=#{result.invoice_number.inspect} " \
          "type=#{upload.invoice_type} (pdf_upload_id=#{pdf_upload_id})"
        )
        next
      end

      # Keep a copy of the uploaded bytes on the invoice so Drive (and audits) still have the
      # original after the user removes the queue row (PdfUpload#destroy nullifies pdf_upload_id).
      invoice = build_invoice_from_extraction(user, upload, file_data, result)

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
      elsif extractable.all? { |r| invoice_number_taken?(user, r.invoice_number, upload.invoice_type) }
        "Las facturas detectadas ya estaban registradas o duplicadas (mismo número para este tipo)."
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

  def build_invoice_from_extraction(user, upload, file_data, result)
    base = {
      status:           :pending,
      invoice_type:     upload.invoice_type,
      invoice_number:   result.invoice_number,
      invoice_date:     result.invoice_date,
      pdf_upload:       upload,
      source_file_data: file_data,
      source_filename:  upload.filename
    }

    if upload.recibida?
      base[:issuer_name] = result.issuer_name
      base[:issuer_nif]  = result.issuer_nif
    else
      base.merge!(user.default_issuer_attributes_for_invoice)
    end

    user.invoices.build(base)
  end

  def invoice_number_taken?(user, invoice_number, type)
    user.invoices.for_accounting.exists?(invoice_type: type, invoice_number: invoice_number) ||
      user.invoices.pending_review.exists?(invoice_type: type, invoice_number: invoice_number)
  end

  def broadcast_update(upload)
    user = upload.user
    t    = upload.invoice_type

    Turbo::StreamsChannel.broadcast_replace_to(
      "pdf_uploads_#{user.id}_#{t}",
      target:  "pdf_upload_#{upload.id}",
      partial: "invoices/pdf_upload_row",
      locals:  { upload: upload }
    )

    broadcast_pending_badges(user)
    broadcast_pending_panel(user, t)
  end

  def broadcast_pending_badges(user)
    %i[emitida recibida].each do |type|
      count = user.invoices.pending_review.where(invoice_type: type).count
      Turbo::StreamsChannel.broadcast_replace_to(
        "pending_badge_#{user.id}_#{type}",
        target:  "pending_badge_#{type}",
        partial: "layouts/pending_badge_for_type",
        locals:  { invoice_type: type.to_s, count: count }
      )
    end
  end

  def broadcast_pending_panel(user, type)
    pending = user.invoices.pending_review.where(invoice_type: type).includes(:invoice_lines).order(:created_at)
    Turbo::StreamsChannel.broadcast_replace_to(
      "pending_invoices_#{user.id}_#{type}",
      target:  "pending_invoices_#{type}",
      partial: "invoices/pending_invoices_panel",
      locals:  { invoices: pending, invoice_type: type.to_s }
    )
  end
end
