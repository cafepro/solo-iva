require "spec_helper"
require_relative "../../app/domain/invoice_totals"

RSpec.describe InvoiceTotals do
  InvoiceTotalsLine = Struct.new(:base_imponible, :iva_amount)

  subject(:totals) { described_class.new(lines) }

  context "with multiple lines at different rates" do
    let(:lines) do
      [
        InvoiceTotalsLine.new(1000.00, 210.00),
        InvoiceTotalsLine.new(500.00, 50.00)
      ]
    end

    it "sums base correctly" do
      expect(totals.base).to eq(1500.00)
    end

    it "sums iva correctly" do
      expect(totals.iva).to eq(260.00)
    end

    it "computes total as base + iva" do
      expect(totals.total).to eq(1760.00)
    end
  end

  context "with no lines" do
    let(:lines) { [] }

    it "returns zero for all fields" do
      expect(totals.base).to eq(0)
      expect(totals.iva).to eq(0)
      expect(totals.total).to eq(0)
    end
  end

  context "with floating point values" do
    let(:lines) { [InvoiceTotalsLine.new(33.33, 6.999)] }

    it "rounds to 2 decimal places" do
      expect(totals.iva).to eq(7.0)
      expect(totals.total).to eq(40.33)
    end
  end
end
