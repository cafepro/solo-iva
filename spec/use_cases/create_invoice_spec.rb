require "rails_helper"

RSpec.describe CreateInvoice do
  let(:user) { create(:user) }

  let(:valid_params) do
    {
      invoice_type:   "emitida",
      invoice_number: "F-001",
      invoice_date:   Date.today,
      issuer_name:    "Acme SL",
      issuer_nif:     "B12345678",
      recipient_name: "Client SL",
      recipient_nif:  "A87654321"
    }
  end

  describe "#call" do
    context "with valid params" do
      it "returns ok: true" do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:ok]).to be true
      end

      it "persists the invoice" do
        expect {
          described_class.new(user: user, params: valid_params).call
        }.to change(Invoice, :count).by(1)
      end

      it "assigns the invoice to the user" do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:invoice].user).to eq(user)
      end
    end

    context "with missing required fields" do
      let(:invalid_params) { { invoice_type: "emitida" } }

      it "returns ok: false" do
        result = described_class.new(user: user, params: invalid_params).call
        expect(result[:ok]).to be false
      end

      it "does not persist the invoice" do
        expect {
          described_class.new(user: user, params: invalid_params).call
        }.not_to change(Invoice, :count)
      end

      it "returns the invoice with errors" do
        result = described_class.new(user: user, params: invalid_params).call
        expect(result[:invoice].errors).not_to be_empty
      end
    end
  end
end
