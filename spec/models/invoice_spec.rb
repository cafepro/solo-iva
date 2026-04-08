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

    it "rejects two confirmed invoices with the same number and type for the same user" do
      existing = create(:invoice, invoice_number: "F-001", invoice_type: :emitida)
      duplicate = build(:invoice, user: existing.user, invoice_number: "F-001", invoice_type: :emitida)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:invoice_number]).to be_present
    end

    it "allows several pending invoices with the same number and type for the same user" do
      user = create(:user)
      create(:invoice, :pending, user: user, invoice_number: "F-001", invoice_type: :recibida)
      other = build(:invoice, :pending, user: user, invoice_number: "F-001", invoice_type: :recibida)
      expect(other).to be_valid
    end

    it "allows pending invoice when a confirmed one already has the same number and type" do
      user = create(:user)
      create(:invoice, user: user, invoice_number: "F-001", invoice_type: :emitida)
      pending_dup = build(:invoice, :pending, user: user, invoice_number: "F-001", invoice_type: :emitida)
      expect(pending_dup).to be_valid
    end

    it "allows same invoice_number for different types when both are confirmed" do
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

  describe "#duplicate_with_confirmed_invoice?" do
    it "is true when a confirmed invoice shares number and type" do
      user = create(:user)
      create(:invoice, user: user, invoice_number: "X-1", invoice_type: :recibida)
      pending = create(:invoice, :pending, user: user, invoice_number: "X-1", invoice_type: :recibida)
      expect(pending.duplicate_with_confirmed_invoice?).to be true
    end

    it "is false when only another pending invoice shares the number" do
      user = create(:user)
      create(:invoice, :pending, user: user, invoice_number: "X-1", invoice_type: :recibida)
      other = create(:invoice, :pending, user: user, invoice_number: "X-1", invoice_type: :recibida)
      expect(other.duplicate_with_confirmed_invoice?).to be false
    end
  end

  describe "#duplicate_with_other_pending_invoice?" do
    it "is true when another pending invoice shares number and type" do
      user = create(:user)
      create(:invoice, :pending, user: user, invoice_number: "X-1", invoice_type: :recibida)
      other = create(:invoice, :pending, user: user, invoice_number: "X-1", invoice_type: :recibida)
      expect(other.duplicate_with_other_pending_invoice?).to be true
    end
  end

  describe ".in_calendar_quarter" do
    it "includes only invoices whose invoice_date falls in that quarter" do
      user = create(:user)
      in_q1 = create(:invoice, user: user, invoice_date: Date.new(2025, 3, 31), invoice_number: "IN")
      create(:invoice, user: user, invoice_date: Date.new(2025, 4, 1), invoice_number: "OUT")

      scope = described_class.where(user: user).in_calendar_quarter(2025, 1)
      expect(scope.pluck(:invoice_number)).to eq([ in_q1.invoice_number ])
    end
  end
end
