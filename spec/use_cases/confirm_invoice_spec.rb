require "rails_helper"

RSpec.describe ConfirmInvoice do
  describe "#call" do
    let(:invoice) { create(:invoice, status: :pending) }

    it "sets the invoice status to confirmed" do
      described_class.new(invoice: invoice).call
      expect(invoice.reload).to be_confirmed
    end

    it "returns the invoice" do
      result = described_class.new(invoice: invoice).call
      expect(result).to eq(invoice)
    end

    it "raises when another confirmed invoice already uses the same number and type" do
      user = create(:user)
      create(:invoice, user: user, invoice_number: "F-001", invoice_type: :emitida)
      pending = create(:invoice, :pending, user: user, invoice_number: "F-001", invoice_type: :emitida)

      expect do
        described_class.new(invoice: pending).call
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
