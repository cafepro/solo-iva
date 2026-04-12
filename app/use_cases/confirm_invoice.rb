class ConfirmInvoice
  def initialize(invoice:)
    @invoice = invoice
  end

  # @return [Hash] :ok (Boolean), :invoice (Invoice with errors when !:ok)
  def call
    if @invoice.update(status: :confirmed)
      enqueue_drive_backup
      { ok: true, invoice: @invoice }
    else
      { ok: false, invoice: @invoice }
    end
  end

  private

  def enqueue_drive_backup
    return if @invoice.google_drive_file_id.present?
    return unless @invoice.user.google_drive_ready?
    return if @invoice.invoice_lines.empty?

    if @invoice.recibida?
      UploadReceivedInvoiceToDriveJob.perform_later(@invoice.id)
    elsif @invoice.emitida?
      UploadIssuedInvoiceToDriveJob.perform_later(@invoice.id)
    end
  end
end
