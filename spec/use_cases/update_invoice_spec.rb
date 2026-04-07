require "rails_helper"

RSpec.describe UpdateInvoice do
  let(:invoice) { create(:invoice) }

  describe "#call" do
    context "with valid params" do
      it "returns ok: true" do
        result = described_class.new(invoice: invoice, params: { invoice_number: "NEW-001" }).call
        expect(result[:ok]).to be true
      end

      it "updates the invoice attribute" do
        described_class.new(invoice: invoice, params: { invoice_number: "NEW-001" }).call
        expect(invoice.reload.invoice_number).to eq("NEW-001")
      end
    end

    context "with invalid params" do
      it "returns ok: false" do
        result = described_class.new(invoice: invoice, params: { invoice_number: "" }).call
        expect(result[:ok]).to be false
      end

      it "does not update the invoice" do
        original_number = invoice.invoice_number
        described_class.new(invoice: invoice, params: { invoice_number: "" }).call
        expect(invoice.reload.invoice_number).to eq(original_number)
      end
    end
  end
end
