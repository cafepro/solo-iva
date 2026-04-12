class CreateInvoice
  def initialize(user:, params:, source_stash_token: nil)
    @user               = user
    @params             = params
    @source_stash_token = source_stash_token
  end

  def call
    invoice = @user.invoices.build(@params)
    apply_source_stash!(invoice)
    ok = invoice.save
    clear_stash_if_ok(ok)
    enqueue_drive_backup(invoice) if ok
    { ok: ok, invoice: invoice }
  end

  private

  def apply_source_stash!(invoice)
    return if @source_stash_token.blank?

    data = InvoiceUploadStash.fetch(@user, @source_stash_token)
    return unless data

    invoice.assign_attributes(source_file_data: data[:data], source_filename: data[:filename])
  end

  def clear_stash_if_ok(ok)
    return unless ok
    return if @source_stash_token.blank?

    InvoiceUploadStash.delete_by_token!(@user, @source_stash_token)
  end

  def enqueue_drive_backup(invoice)
    return unless invoice.recibida? && invoice.confirmed?
    return if invoice.google_drive_file_id.present?
    return unless invoice.user.google_drive_ready?

    UploadReceivedInvoiceToDriveJob.perform_later(invoice.id)
  end
end
