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
  end
end
