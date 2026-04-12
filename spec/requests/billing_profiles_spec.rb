require "rails_helper"

RSpec.describe "BillingProfiles", type: :request do
  let(:user) { create(:user, password: "password123", password_confirmation: "password123") }

  before { sign_in user, scope: :user }

  describe "PATCH /billing_profile" do
    it "persists billing fields and shows them after redirect" do
      patch billing_profile_path, params: {
        user: {
          billing_display_name: "Coworking Demo",
          billing_nif:          "12345678Z",
          billing_address_line: "Calle Mayor 1",
          billing_city:         "Gijón"
        }
      }

      expect(response).to redirect_to(billing_profile_path)
      follow_redirect!
      expect(response.body).to include("Coworking Demo")
      expect(response.body).to include("Calle Mayor 1")
      expect(user.reload.billing_display_name).to eq("Coworking Demo")
    end
  end
end
