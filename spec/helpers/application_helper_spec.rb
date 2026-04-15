require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#page_section_heading" do
    it "prefers section_title when set" do
      allow(helper).to receive(:content_for?).with(:section_title).and_return(true)
      allow(helper).to receive(:content_for).with(:section_title).and_return("Subir facturas")
      expect(helper.page_section_heading).to eq("Subir facturas")
    end

    it "strips the SoloIVA suffix from title" do
      allow(helper).to receive(:content_for?).with(:section_title).and_return(false)
      allow(helper).to receive(:content_for).with(:title).and_return("Modelo 303 — SoloIVA")
      expect(helper.page_section_heading).to eq("Modelo 303")
    end

    it "falls back to SoloIVA when title is blank" do
      allow(helper).to receive(:content_for?).with(:section_title).and_return(false)
      allow(helper).to receive(:content_for).with(:title).and_return("")
      expect(helper.page_section_heading).to eq("SoloIVA")
    end
  end
end
