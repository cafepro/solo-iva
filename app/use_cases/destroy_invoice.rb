class DestroyInvoice
  def initialize(invoice:)
    @invoice = invoice
  end

  def call
    @invoice.destroy
  end
end
