require "rails_helper"

RSpec.describe "Invoices index period filter", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  before { sign_in user, scope: :user }

  it "lists only invoices in the selected calendar quarter" do
    create(:invoice, user: user, invoice_date: Date.new(2025, 2, 15), invoice_number: "Q1-A")
    create(:invoice, user: user, invoice_date: Date.new(2025, 5, 10), invoice_number: "Q2-B")

    get invoices_path(year: 2025, quarter: 1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Q1-A")
    expect(response.body).not_to include("Q2-B")
  end

  it "ignores invalid period params" do
    create(:invoice, user: user, invoice_date: Date.new(2025, 2, 15), invoice_number: "ANY")

    get invoices_path(year: 1999, quarter: 1)

    expect(response.body).to include("ANY")
  end
end
