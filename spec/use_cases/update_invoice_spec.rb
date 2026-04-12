require "rails_helper"

RSpec.describe UpdateInvoice do
  let(:invoice) { create(:invoice) }

  describe "#call" do
    context "with a source stash token" do
      let(:stash_token) do
        InvoiceUploadStash.store!(user: invoice.user, file_data: "IMG".b, filename: "scan.jpg")
      end

      it "copies the stashed file and deletes the stash on success" do
        result = described_class.new(
          invoice: invoice, params: { notes: "ok" }, source_stash_token: stash_token
        ).call

        expect(result[:ok]).to be true
        expect(invoice.reload.source_filename).to eq("scan.jpg")
        expect(invoice.source_file_data).to eq("IMG".b)
        expect(InvoiceUploadStash.where(token: stash_token)).not_to exist
      end

      it "does not delete the stash when update fails" do
        result = described_class.new(
          invoice: invoice, params: { invoice_number: "" }, source_stash_token: stash_token
        ).call

        expect(result[:ok]).to be false
        expect(InvoiceUploadStash.where(token: stash_token)).to exist
      end
    end

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
