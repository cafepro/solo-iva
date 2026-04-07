require "rails_helper"

RSpec.describe InvoiceLine, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:invoice) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:iva_rate) }
    it { is_expected.to validate_presence_of(:base_imponible) }
    it { is_expected.to validate_numericality_of(:base_imponible) }
    it { is_expected.to validate_inclusion_of(:iva_rate).in_array(InvoiceLine::VALID_RATES) }
  end

  describe "#calculate_iva_amount" do
    it "sets iva_amount before save" do
      line = create(:invoice_line, iva_rate: 21, base_imponible: 1000.0)
      expect(line.iva_amount).to eq(210.0)
    end

    it "rounds iva_amount to 2 decimals" do
      line = create(:invoice_line, iva_rate: 21, base_imponible: 33.33)
      expect(line.iva_amount).to eq(7.0)
    end
  end
end
