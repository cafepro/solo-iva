class BulkCreateInvoices
  Result = Struct.new(:saved, :skipped, keyword_init: true)

  def initialize(user:, invoices_params:, source_stash_token: nil)
    @user               = user
    @invoices_params    = invoices_params
    @source_stash_token = source_stash_token
  end

  def call
    stash_data = fetch_stash_data
    saved      = []
    skipped    = []

    @invoices_params.each do |raw|
      params_hash = merge_stash(raw, stash_data)
      result      = CreateInvoice.new(user: @user, params: params_hash).call
      if result[:ok]
        saved << result[:invoice]
      else
        skipped << result[:invoice]
      end
    end

    if @source_stash_token.present? && saved.any?
      InvoiceUploadStash.delete_by_token!(@user, @source_stash_token)
    end

    Result.new(saved: saved, skipped: skipped)
  end

  private

  def fetch_stash_data
    return nil if @source_stash_token.blank?

    InvoiceUploadStash.fetch(@user, @source_stash_token)
  end

  def merge_stash(raw_params, stash_data)
    h = raw_params.to_h.symbolize_keys
    return h unless stash_data

    h.merge(source_file_data: stash_data[:data], source_filename: stash_data[:filename])
  end
end
