require "rails_helper"

RSpec.describe CalculateModelo303 do
  let(:user)    { create(:user) }
  let(:year)    { 2024 }
  let(:quarter) { 1 }

  subject(:use_case) { described_class.new(user: user, year: year, quarter: quarter) }

  describe "#call" do
    it "returns a Modelo303Report" do
      expect(use_case.call).to be_a(Modelo303Report)
    end

    context "with issued and received invoices in the quarter" do
      before do
        issued   = create(:invoice, user: user, invoice_type: :emitida,  invoice_date: Date.new(2024, 1, 15))
        received = create(:invoice, user: user, invoice_type: :recibida, invoice_date: Date.new(2024, 2, 10))

        create(:invoice_line, invoice: issued,   iva_rate: 21, base_imponible: 1000.0, iva_amount: 210.0)
        create(:invoice_line, invoice: received, iva_rate: 21, base_imponible: 400.0,  iva_amount: 84.0)
      end

      it "calculates IVA devengado from issued invoices" do
        result = use_case.call.to_h
        expect(result[:casilla_02]).to eq(210.0)
      end

      it "calculates IVA deducible from received invoices" do
        result = use_case.call.to_h
        expect(result[:casilla_29]).to eq(84.0)
      end

      it "calculates the resultado correctly" do
        result = use_case.call.to_h
        expect(result[:casilla_64]).to eq(210.0 - 84.0)
      end
    end

    context "with invoices outside the requested quarter" do
      before do
        invoice = create(:invoice, user: user, invoice_type: :emitida, invoice_date: Date.new(2024, 7, 1))
        create(:invoice_line, invoice: invoice, iva_rate: 21, base_imponible: 1000.0, iva_amount: 210.0)
      end

      it "excludes them from the report" do
        result = use_case.call.to_h
        expect(result[:casilla_02]).to eq(0.0)
      end
    end
  end
end
