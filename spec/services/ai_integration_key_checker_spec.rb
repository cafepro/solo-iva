require "rails_helper"

RSpec.describe AiIntegrationKeyChecker do
  let(:conn) { instance_double(Faraday::Connection) }

  describe ".call gemini" do
    it "returns ok when API returns models" do
      allow(conn).to receive(:get).and_return(
        double(status: 200, body: { "models" => [ { "name" => "models/x" } ] })
      )

      result = described_class.call(provider: "gemini", api_key: "k", faraday: conn)
      expect(result[:ok]).to be true
      expect(result[:message]).to include("Gemini")
    end

    it "returns failure on 401" do
      allow(conn).to receive(:get).and_return(
        double(status: 401, body: { "error" => { "message" => "Invalid" } })
      )

      result = described_class.call(provider: "gemini", api_key: "bad", faraday: conn)
      expect(result[:ok]).to be false
      expect(result[:message]).to include("Invalid")
    end

    it "returns failure when models key missing" do
      allow(conn).to receive(:get).and_return(double(status: 200, body: {}))

      result = described_class.call(provider: "gemini", api_key: "k", faraday: conn)
      expect(result[:ok]).to be false
    end
  end

  describe ".call groq" do
    it "returns ok when API returns data list" do
      allow(conn).to receive(:get).and_return(
        double(status: 200, body: { "data" => [ { "id" => "llama-3-3-70b-versatile" } ] })
      )

      result = described_class.call(provider: "groq", api_key: "gsk_test", faraday: conn)
      expect(result[:ok]).to be true
      expect(result[:message]).to include("Groq")
    end

    it "returns failure on 401" do
      allow(conn).to receive(:get).and_return(
        double(status: 401, body: { "error" => { "message" => "Invalid API Key" } })
      )

      result = described_class.call(provider: "groq", api_key: "x", faraday: conn)
      expect(result[:ok]).to be false
      expect(result[:message]).to include("Invalid API Key")
    end
  end

  describe "blank key" do
    it "returns failure without HTTP" do
      result = described_class.call(provider: "gemini", api_key: "   ")
      expect(result[:ok]).to be false
      expect(result[:message]).to include("clave")
    end
  end
end
