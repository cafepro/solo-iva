require "rails_helper"

RSpec.describe "ServiceTemplates", type: :request do
  let(:user) { create(:user, password: "password123", password_confirmation: "password123") }
  let!(:template) { create(:service_template, user: user, name: "Mensual", billing_period: "month") }

  before { sign_in user, scope: :user }

  describe "GET /service_templates/:id.json" do
    it "devuelve JSON con los campos esperados" do
      get service_template_path(template, format: :json)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["id"]).to eq(template.id)
      expect(body["name"]).to eq("Mensual")
      expect(body["billing_period"]).to eq("month")
      expect(body["default_description"]).to eq(template.default_description)
    end
  end

  describe "POST /service_templates" do
    it "crea una plantilla" do
      expect {
        post service_templates_path, params: {
          service_template: {
            name: "Semanal",
            billing_period: "week",
            default_description: "Cuota semana",
            default_base_imponible: 50,
            default_iva_rate: 10
          }
        }
      }.to change(ServiceTemplate, :count).by(1)

      expect(response).to redirect_to(service_templates_path)
    end
  end
end
