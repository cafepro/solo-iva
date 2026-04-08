require "rails_helper"

RSpec.describe ConfirmInvoice do
  describe "#call" do
    let(:invoice) { create(:invoice, :pending) }

    it "sets the invoice status to confirmed" do
      described_class.new(invoice: invoice).call
      expect(invoice.reload).to be_confirmed
    end

    it "returns ok and the invoice" do
      result = described_class.new(invoice: invoice).call
      expect(result[:ok]).to be true
      expect(result[:invoice]).to eq(invoice)
    end

    it "returns ok false when another confirmed invoice already uses the same number and type" do
      user = create(:user)
      create(:invoice, user: user, invoice_number: "F-001", invoice_type: :emitida)
      pending = create(:invoice, :pending, user: user, invoice_number: "F-001", invoice_type: :emitida)

      result = described_class.new(invoice: pending).call
      expect(result[:ok]).to be false
      expect(pending.reload).to be_pending
      expect(result[:invoice].errors[:invoice_number]).to be_present
    end
  end
end
