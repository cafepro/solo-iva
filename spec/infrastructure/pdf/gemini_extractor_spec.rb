require "rails_helper"

RSpec.describe Pdf::GeminiExtractor do
  let(:sample_text) { "Factura F-001\nFecha: 01/01/2024\nBase: 100€" }
  let(:client) { instance_double(Pdf::Clients::GeminiClient) }

  subject(:extractor) { described_class.new(sample_text, client: client) }

  describe "#extract" do
    context "when the API returns a single invoice" do
      let(:gemini_response) do
        {
          "candidates" => [ {
            "content" => {
              "parts" => [ {
                "text" => JSON.generate({
                  "invoices" => [ {
                    "invoice_number" => "F-001",
                    "invoice_date"   => "2024-01-01",
                    "issuer_name"    => "Acme SL",
                    "issuer_nif"     => "B12345678",
                    "lines"          => [ { "iva_rate" => 21, "base_imponible" => 100.0, "iva_amount" => 21.0 } ]
                  } ]
                })
              } ]
            }
          } ]
        }
      end

      let(:faraday_response) do
        instance_double(Faraday::Response, body: gemini_response, success?: true)
      end

      before do
        allow(client).to receive(:generate_content).and_return(faraday_response)
      end

      it "returns an array with one PdfExtractionResult" do
        results = extractor.extract
        expect(results).to be_an(Array)
        expect(results.length).to eq(1)
        expect(results.first).to be_a(PdfExtractionResult)
      end

      it "maps the invoice number" do
        expect(extractor.extract.first.invoice_number).to eq("F-001")
      end

      it "parses the invoice date" do
        expect(extractor.extract.first.invoice_date).to eq(Date.new(2024, 1, 1))
      end

      it "maps the IVA lines" do
        lines = extractor.extract.first.lines
        expect(lines.length).to eq(1)
        expect(lines.first[:iva_rate]).to eq(21)
      end
    end

    context "when the API returns multiple invoices" do
      let(:gemini_response) do
        {
          "candidates" => [ {
            "content" => {
              "parts" => [ {
                "text" => JSON.generate({
                  "invoices" => [
                    { "invoice_number" => "F-001", "invoice_date" => "2024-01-01",
                      "issuer_name" => "Acme SL", "issuer_nif" => "B12345678",
                      "lines" => [ { "iva_rate" => 21, "base_imponible" => 100.0, "iva_amount" => 21.0 } ] },
                    { "invoice_number" => "F-002", "invoice_date" => "2024-01-01",
                      "issuer_name" => "Beta SL", "issuer_nif" => "A87654321",
                      "lines" => [ { "iva_rate" => 10, "base_imponible" => 50.0, "iva_amount" => 5.0 } ] }
                  ]
                })
              } ]
            }
          } ]
        }
      end

      let(:faraday_response) do
        instance_double(Faraday::Response, body: gemini_response, success?: true)
      end

      before do
        allow(client).to receive(:generate_content).and_return(faraday_response)
      end

      it "returns an array with all invoices" do
        results = extractor.extract
        expect(results.length).to eq(2)
        expect(results.map(&:invoice_number)).to eq([ "F-001", "F-002" ])
      end
    end

    context "when the API call fails" do
      before { allow(client).to receive(:generate_content).and_raise(Faraday::Error, "connection refused") }

      it "returns an empty array without raising" do
        expect(extractor.extract).to eq([])
      end
    end
  end
end
