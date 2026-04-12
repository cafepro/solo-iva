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

    context "with a received invoice and Google Drive enabled" do
      before do
        user.update!(google_drive_refresh_token: "t", google_drive_sync_enabled: true)
      end

      let(:recibida_params) do
        valid_params.merge(
          invoice_type: "recibida",
          invoice_lines_attributes: { "0" => { iva_rate: 21, base_imponible: "100.0" } }
        )
      end

      it "enqueues Drive backup" do
        expect {
          described_class.new(user: user, params: recibida_params).call
        }.to have_enqueued_job(UploadReceivedInvoiceToDriveJob).with(kind_of(Integer))
      end
    end

    context "with an issued invoice, lines and Google Drive enabled" do
      before do
        user.update!(google_drive_refresh_token: "t", google_drive_sync_enabled: true)
      end

      let(:emitida_params) do
        valid_params.merge(
          invoice_lines_attributes: { "0" => { iva_rate: 21, base_imponible: "50.0" } }
        )
      end

      it "enqueues issued invoice PDF upload to Drive" do
        expect {
          described_class.new(user: user, params: emitida_params).call
        }.to have_enqueued_job(UploadIssuedInvoiceToDriveJob).with(kind_of(Integer))
      end
    end

    context "with auto_invoice_number for emitida" do
      before do
        user.update!(
          invoice_number_prefix:      "T",
          invoice_number_digit_count: 2,
          invoice_number_next:        5
        )
      end

      let(:auto_params) do
        valid_params.merge(
          invoice_number:           "IGNORED",
          invoice_lines_attributes: { "0" => { iva_rate: 21, base_imponible: "10.0" } }
        )
      end

      it "assigns next sequential number and increments counter" do
        result = described_class.new(user: user, params: auto_params, auto_invoice_number: true).call
        expect(result[:ok]).to be true
        expect(result[:invoice].invoice_number).to eq("T05")
        expect(user.reload.invoice_number_next).to eq(6)
      end
    end

    context "with a source stash token" do
      let(:stash_token) do
        InvoiceUploadStash.store!(user: user, file_data: "%PDF-1".b, filename: "orig.pdf")
      end

      let(:recibida_with_lines) do
        valid_params.merge(
          invoice_type: "recibida",
          invoice_lines_attributes: { "0" => { iva_rate: 21, base_imponible: "100.0" } }
        )
      end

      it "copies the stashed file onto the invoice and deletes the stash" do
        result = described_class.new(
          user: user, params: recibida_with_lines, source_stash_token: stash_token
        ).call

        expect(result[:ok]).to be true
        inv = result[:invoice].reload
        expect(inv.source_filename).to eq("orig.pdf")
        expect(inv.source_file_data).to eq("%PDF-1".b)
        expect(InvoiceUploadStash.where(token: stash_token)).not_to exist
      end

      it "does not delete the stash when save fails" do
        result = described_class.new(
          user: user, params: { invoice_type: "emitida" }, source_stash_token: stash_token
        ).call

        expect(result[:ok]).to be false
        expect(InvoiceUploadStash.where(token: stash_token)).to exist
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
