require "spec_helper"
require_relative "../../app/domain/pdf_extraction_result"

RSpec.describe PdfExtractionResult do
  let(:full_result) do
    described_class.new(
      invoice_number: "F-001",
      invoice_date:   Date.new(2024, 3, 15),
      issuer_name:    "Acme SL",
      issuer_nif:     "B12345678",
      lines:          [{ iva_rate: 21, base_imponible: 100.0, iva_amount: 21.0 }]
    )
  end

  let(:empty_result) do
    described_class.new(invoice_number: nil, invoice_date: nil,
                        issuer_name: nil, issuer_nif: nil, lines: [])
  end

  describe "#empty?" do
    it "returns false when any field is present" do
      expect(full_result).not_to be_empty
    end

    it "returns true when all fields are nil/blank" do
      expect(empty_result).to be_empty
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      hash = full_result.to_h
      expect(hash[:invoice_number]).to eq("F-001")
      expect(hash[:lines].length).to eq(1)
    end
  end
end
