class CreateInvoice
  def initialize(user:, params:)
    @user   = user
    @params = params
  end

  def call
    invoice = @user.invoices.build(@params)
    { ok: invoice.save, invoice: invoice }
  end
end
