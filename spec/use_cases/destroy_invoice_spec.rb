require "rails_helper"

RSpec.describe DestroyInvoice do
  let!(:invoice) { create(:invoice) }

  describe "#call" do
    it "deletes the invoice from the database" do
      expect {
        described_class.new(invoice: invoice).call
      }.to change(Invoice, :count).by(-1)
    end

    it "destroys associated invoice lines" do
      create(:invoice_line, invoice: invoice)
      expect {
        described_class.new(invoice: invoice).call
      }.to change(InvoiceLine, :count).by(-1)
    end
  end
end
