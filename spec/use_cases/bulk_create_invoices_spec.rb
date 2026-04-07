require "rails_helper"

RSpec.describe BulkCreateInvoices do
  let(:user) { create(:user) }

  let(:valid_params) do
    [
      { invoice_type: "recibida", invoice_number: "F-001", invoice_date: Date.today,
        issuer_name: "Acme SL", issuer_nif: "B12345678" },
      { invoice_type: "recibida", invoice_number: "F-002", invoice_date: Date.today,
        issuer_name: "Beta SL", issuer_nif: "A87654321" }
    ]
  end

  describe "#call" do
    it "saves all valid invoices" do
      result = described_class.new(user: user, invoices_params: valid_params).call
      expect(result.saved.length).to eq(2)
      expect(result.skipped).to be_empty
    end

    it "persists them to the database" do
      expect {
        described_class.new(user: user, invoices_params: valid_params).call
      }.to change(Invoice, :count).by(2)
    end

    context "when one invoice is invalid" do
      let(:mixed_params) do
        valid_params + [{ invoice_type: "recibida", invoice_number: "", invoice_date: Date.today }]
      end

      it "saves the valid ones and skips the invalid" do
        result = described_class.new(user: user, invoices_params: mixed_params).call
        expect(result.saved.length).to eq(2)
        expect(result.skipped.length).to eq(1)
      end
    end
  end
end
