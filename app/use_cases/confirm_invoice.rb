class ConfirmInvoice
  def initialize(invoice:)
    @invoice = invoice
  end

  # @return [Hash] :ok (Boolean), :invoice (Invoice with errors when !:ok)
  def call
    if @invoice.update(status: :confirmed)
      { ok: true, invoice: @invoice }
    else
      { ok: false, invoice: @invoice }
    end
  end
end
