class ConfirmInvoice
  def initialize(invoice:)
    @invoice = invoice
  end

  def call
    @invoice.update!(status: :confirmed)
    @invoice
  end
end
