require "rails_helper"

RSpec.describe ReportsHelper, type: :helper do
  describe "#modelo303_copy_value" do
    it "formats with Spanish thousands and decimal separators" do
      expect(helper.modelo303_copy_value(1234.56)).to eq("1.234,56")
    end

    it "handles negatives" do
      expect(helper.modelo303_copy_value(-100)).to eq("-100,00")
    end
  end
end
