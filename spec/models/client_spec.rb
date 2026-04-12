require "rails_helper"

RSpec.describe Client, type: :model do
  describe "#attributes_for_invoice_recipient" do
    it "devuelve claves alineadas con el snapshot de factura emitida" do
      client = build(:client, name: "ACME", city: "Gijón", nif: nil, country: nil)
      attrs = client.attributes_for_invoice_recipient

      expect(attrs[:recipient_name]).to eq("ACME")
      expect(attrs[:recipient_city]).to eq("Gijón")
      expect(attrs[:recipient_nif]).to eq("")
      expect(attrs[:recipient_country]).to eq("España")
    end
  end
end
