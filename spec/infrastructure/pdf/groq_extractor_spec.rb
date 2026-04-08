require "rails_helper"

RSpec.describe Pdf::GroqExtractor do
  let(:sample_text) { "Factura F-001\nFecha: 01/01/2024\nBase: 100€" }
  let(:client) { instance_double(Pdf::Clients::GroqClient) }

  subject(:extractor) { described_class.new(sample_text, client: client) }

  describe "#extract" do
    let(:groq_response) do
      {
        "choices" => [ {
          "message" => {
            "role"    => "assistant",
            "content" => JSON.generate({
              "invoices" => [ {
                "invoice_number" => "F-001",
                "invoice_date"   => "2024-01-01",
                "issuer_name"    => "Acme SL",
                "issuer_nif"     => "B12345678",
                "lines"          => [ { "iva_rate" => 21, "base_imponible" => 100.0, "iva_amount" => 21.0 } ]
              } ]
            })
          }
        } ]
      }
    end

    let(:faraday_response) do
      instance_double(Faraday::Response, body: groq_response, success?: true)
    end

    before do
      allow(client).to receive(:chat_completion).and_return(faraday_response)
    end

    it "returns PdfExtractionResult instances" do
      results = extractor.extract
      expect(results.length).to eq(1)
      expect(results.first).to be_a(PdfExtractionResult)
      expect(results.first.invoice_number).to eq("F-001")
    end

    context "when the API call fails" do
      before { allow(client).to receive(:chat_completion).and_raise(Faraday::Error, "timeout") }

      it "returns an empty array without raising" do
        expect(extractor.extract).to eq([])
      end
    end
  end
end
