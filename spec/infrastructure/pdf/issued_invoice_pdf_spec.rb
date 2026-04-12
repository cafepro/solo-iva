require "rails_helper"

RSpec.describe Pdf::IssuedInvoicePdf do
  it "renders a PDF for an emitida" do
    user = create(:user, email: "a@b.com", billing_phone: "+34 600 000 000")
    invoice = create(
      :invoice,
      user:           user,
      invoice_type:   :emitida,
      invoice_number: "F2026001",
      issuer_name:    "Test SL",
      issuer_nif:     "B00000000",
      recipient_name: "Cliente",
      invoice_lines_attributes: [
        { description: "Servicio", iva_rate: 21, base_imponible: 100.0 }
      ]
    )
    io = described_class.render(invoice)
    expect(io.read).to start_with("%PDF")
  end

  it "raises for recibida" do
    invoice = create(:invoice, :recibida)
    expect { described_class.render(invoice) }.to raise_error(ArgumentError)
  end
end
