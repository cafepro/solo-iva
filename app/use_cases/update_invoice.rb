class UpdateInvoice
  def initialize(invoice:, params:, source_stash_token: nil)
    @invoice            = invoice
    @params             = params
    @source_stash_token = source_stash_token
  end

  def call
    apply_source_stash!
    ok = @invoice.update(@params)
    clear_stash_if_ok(ok)
    enqueue_drive_backup_if_needed(ok)
    { ok: ok, invoice: @invoice }
  end

  private

  def apply_source_stash!
    return if @source_stash_token.blank?

    data = InvoiceUploadStash.fetch(@invoice.user, @source_stash_token)
    return unless data

    @invoice.assign_attributes(source_file_data: data[:data], source_filename: data[:filename])
  end

  def clear_stash_if_ok(ok)
    return unless ok
    return if @source_stash_token.blank?

    InvoiceUploadStash.delete_by_token!(@invoice.user, @source_stash_token)
  end

  def enqueue_drive_backup_if_needed(ok)
    return unless ok

    inv = @invoice.reload
    return unless inv.confirmed?
    return if inv.google_drive_file_id.present?
    return unless inv.user.google_drive_ready?
    return if inv.invoice_lines.empty?

    if inv.recibida?
      UploadReceivedInvoiceToDriveJob.perform_later(inv.id)
    elsif inv.emitida?
      UploadIssuedInvoiceToDriveJob.perform_later(inv.id)
    end
  end
end
