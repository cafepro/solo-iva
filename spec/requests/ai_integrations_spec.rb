require "rails_helper"

RSpec.describe "AiIntegrations", type: :request do
  let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

  before { sign_in user, scope: :user }

  describe "GET /ai_integrations" do
    it "renders the settings page" do
      get ai_integrations_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Integraciones con IA")
    end
  end

  describe "PATCH /ai_integrations" do
    it "stores encrypted Gemini key and redirects" do
      patch ai_integrations_path, params: {
        user: { gemini_api_key: "AIza_test_key_12345" }
      }

      expect(response).to redirect_to(ai_integrations_path)
      expect(user.reload.gemini_api_key).to eq("AIza_test_key_12345")
      expect(user.gemini_api_key_configured?).to be true
    end

    it "clears Gemini key when remove checkbox is set" do
      user.update!(gemini_api_key: "secret-gemini")

      patch ai_integrations_path, params: {
        user: { remove_gemini_api_key: "1" }
      }

      expect(response).to redirect_to(ai_integrations_path)
      expect(user.reload.gemini_api_key).to be_nil
    end
  end
end
