require "rails_helper"

RSpec.describe Invoice, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:invoice_lines).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:invoice_type) }
    it { is_expected.to validate_presence_of(:invoice_date) }
    it { is_expected.to validate_presence_of(:invoice_number) }

    it "rejects duplicate invoice_number for the same user and type" do
      existing = create(:invoice, invoice_number: "F-001", invoice_type: :emitida)
      duplicate = build(:invoice, user: existing.user, invoice_number: "F-001", invoice_type: :emitida)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:invoice_number]).to be_present
    end

    it "allows same invoice_number for different types" do
      existing = create(:invoice, invoice_number: "F-001", invoice_type: :emitida)
      other = build(:invoice, user: existing.user, invoice_number: "F-001", invoice_type: :recibida)
      expect(other).to be_valid
    end
  end

  describe "#totals" do
    let(:invoice) { create(:invoice) }

    before do
      # iva_amount is recalculated by before_save: 100 * 21% = 21, 200 * 10% = 20
      create(:invoice_line, invoice: invoice, iva_rate: 21, base_imponible: 100.0)
      create(:invoice_line, invoice: invoice, iva_rate: 10, base_imponible: 200.0)
      invoice.invoice_lines.reload
    end

    it "returns an InvoiceTotals object" do
      expect(invoice.totals).to be_a(InvoiceTotals)
    end

    it "delegates total_base" do
      expect(invoice.total_base).to eq(300.0)
    end

    it "delegates total_iva" do
      expect(invoice.total_iva).to eq(41.0)
    end

    it "delegates total" do
      expect(invoice.total).to eq(341.0)
    end
  end

  describe "#quarter" do
    it "delegates to QuarterCalculator" do
      invoice = build(:invoice, invoice_date: Date.new(2024, 5, 1))
      expect(invoice.quarter).to eq(2)
    end
  end

  describe "#year" do
    it "returns the invoice date year" do
      invoice = build(:invoice, invoice_date: Date.new(2024, 5, 1))
      expect(invoice.year).to eq(2024)
    end
  end
end
