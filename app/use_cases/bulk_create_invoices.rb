class BulkCreateInvoices
  Result = Struct.new(:saved, :skipped, keyword_init: true)

  def initialize(user:, invoices_params:)
    @user            = user
    @invoices_params = invoices_params
  end

  def call
    saved   = []
    skipped = []

    @invoices_params.each do |params|
      result = CreateInvoice.new(user: @user, params: params).call
      result[:ok] ? saved << result[:invoice] : skipped << result[:invoice]
    end

    Result.new(saved: saved, skipped: skipped)
  end
end
