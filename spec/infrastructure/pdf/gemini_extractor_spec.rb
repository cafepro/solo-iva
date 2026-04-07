require "rails_helper"

RSpec.describe Pdf::GeminiExtractor do
  let(:api_key) { "test-api-key" }
  let(:sample_text) { "Factura F-001\nFecha: 01/01/2024\nBase: 100€" }

  subject(:extractor) { described_class.new(sample_text, api_key: api_key) }

  describe "#extract" do
    context "when the API returns valid JSON" do
      let(:gemini_response) do
        {
          "candidates" => [{
            "content" => {
              "parts" => [{
                "text" => JSON.generate({
                  "invoice_number" => "F-001",
                  "invoice_date"   => "2024-01-01",
                  "issuer_name"    => "Acme SL",
                  "issuer_nif"     => "B12345678",
                  "lines"          => [{ "iva_rate" => 21, "base_imponible" => 100.0, "iva_amount" => 21.0 }]
                })
              }]
            }
          }]
        }
      end

      before do
        fake_conn = instance_double(Faraday::Connection)
        fake_resp = instance_double(Faraday::Response, body: gemini_response)
        allow(Faraday).to receive(:new).and_return(fake_conn)
        allow(fake_conn).to receive(:post).and_return(fake_resp)
      end

      it "returns a PdfExtractionResult" do
        expect(extractor.extract).to be_a(PdfExtractionResult)
      end

      it "maps the invoice number" do
        expect(extractor.extract.invoice_number).to eq("F-001")
      end

      it "parses the invoice date" do
        expect(extractor.extract.invoice_date).to eq(Date.new(2024, 1, 1))
      end

      it "maps the IVA lines" do
        lines = extractor.extract.lines
        expect(lines.length).to eq(1)
        expect(lines.first[:iva_rate]).to eq(21)
      end
    end

    context "when the API call fails" do
      before do
        allow(Faraday).to receive(:new).and_raise(Faraday::Error, "connection refused")
      end

      it "returns an empty result without raising" do
        result = extractor.extract
        expect(result).to be_a(PdfExtractionResult)
        expect(result).to be_empty
      end
    end
  end
end
