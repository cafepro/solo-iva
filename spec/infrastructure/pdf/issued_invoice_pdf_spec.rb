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

  it "prefers invoice_pdf_header_title for the PDF banner when set" do
    user = create(
      :user,
      invoice_pdf_header_title: "Cabecera personalizada",
      billing_display_name:     "Otro nombre"
    )
    invoice = create(
      :invoice,
      user:           user,
      invoice_type:   :emitida,
      invoice_number: "F1",
      issuer_name:    "Nombre emisor factura",
      issuer_nif:     "B00000000",
      recipient_name: "Cliente",
      invoice_lines_attributes: [
        { description: "L", iva_rate: 21, base_imponible: 10.0 }
      ]
    )
    expect(described_class.send(:header_title, invoice)).to eq("Cabecera personalizada")
    expect(described_class.render(invoice).read).to start_with("%PDF")
  end

  it "raises for recibida" do
    invoice = create(:invoice, :recibida)
    expect { described_class.render(invoice) }.to raise_error(ArgumentError)
  end
end
