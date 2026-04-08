require "rails_helper"

RSpec.describe "PdfUploads", type: :request do
  include Devise::Test::IntegrationHelpers

  describe "DELETE /pdf_uploads/:id" do
    let(:user) { create(:user) }

    before { sign_in user, scope: :user }

    it "removes a pending upload owned by the user" do
      upload = create(:pdf_upload, user: user, status: :pending)

      delete pdf_upload_path(upload), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(PdfUpload.exists?(upload.id)).to be false
    end

    it "rejects destroying another user's upload" do
      other = create(:user)
      upload = create(:pdf_upload, user: other, status: :pending)

      delete pdf_upload_path(upload), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:not_found)
      expect(PdfUpload.exists?(upload.id)).to be true
    end

    it "rejects destroying a completed upload" do
      upload = create(:pdf_upload, user: user, status: :done)

      delete pdf_upload_path(upload), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(PdfUpload.exists?(upload.id)).to be true
    end
  end
end
