require "rails_helper"

RSpec.describe Pdf::HeuristicInvoiceExtractor do
  let(:serenos_text) do
    <<~TEXT
      SERENOS GIJÓN,                                         Nº Factura: S261425                                  Base          15,04€
      B33918186.
                                                             Fecha:  20/01/26                           21% I.V.A.           3,16€
      CANGAS DE ONÍS, 13-2ºI                                                                                      Total         18,20€
    TEXT
  end

  it "extracts invoice from Serenos-style PDF text" do
    results = described_class.new(serenos_text).extract

    expect(results.size).to eq(1)
    inv = results.first
    expect(inv.invoice_number).to eq("S261425")
    expect(inv.invoice_date).to eq(Date.new(2026, 1, 20))
    expect(inv.issuer_name).to eq("SERENOS GIJÓN")
    expect(inv.issuer_nif).to eq("B33918186")
    expect(inv.lines.size).to eq(1)
    expect(inv.lines.first[:iva_rate]).to eq(21)
    expect(inv.lines.first[:base_imponible]).to eq(15.04)
    expect(inv.lines.first[:iva_amount]).to eq(3.16)
  end

  it "returns empty array when required fields are missing" do
    expect(described_class.new("sin datos de factura").extract).to eq([])
  end

  it "accepts Fecha de factura: (common on utility PDFs) instead of only Fecha:" do
    text = <<~TEXT
      EMPRESA MUNICIPAL
      Nº Factura: 1261042548
      Fecha de factura: 10/02/2026
      Base          100,00€
      21% I.V.A.           21,00 €
    TEXT

    results = described_class.new(text).extract
    expect(results.size).to eq(1)
    expect(results.first.invoice_number).to eq("1261042548")
    expect(results.first.invoice_date).to eq(Date.new(2026, 2, 10))
  end
end
