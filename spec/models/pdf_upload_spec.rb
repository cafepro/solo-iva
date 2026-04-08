require "rails_helper"

RSpec.describe PdfUpload, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_presence_of(:file_data) }
  end

  describe "status transitions" do
    let(:upload) { create(:pdf_upload) }

    it "starts as pending" do
      expect(upload).to be_pending
    end

    it "can transition to processing" do
      upload.processing!
      expect(upload).to be_processing
    end

    it "can transition to done" do
      upload.done!
      expect(upload).to be_done
    end

    it "can transition to failed" do
      upload.failed!
      expect(upload).to be_failed
    end
  end
end
