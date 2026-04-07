class UpdateInvoice
  def initialize(invoice:, params:)
    @invoice = invoice
    @params  = params
  end

  def call
    { ok: @invoice.update(@params), invoice: @invoice }
  end
end
