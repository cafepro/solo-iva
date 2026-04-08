require "rails_helper"

RSpec.describe ParsePdfInvoice do
  let(:source) { StringIO.new("fake pdf content") }

  before do
    allow_any_instance_of(ParsePdfInvoice).to receive(:extract_text).and_return("invoice text")
  end

  describe "#call" do
    context "when Gemini returns a valid result" do
      let(:gemini_results) do
        [ PdfExtractionResult.new(
          invoice_number: "F-001",
          invoice_date:   Date.new(2024, 1, 1),
          issuer_name:    "Acme SL",
          issuer_nif:     "B12345678",
          lines:          [ { iva_rate: 21, base_imponible: 100.0, iva_amount: 21.0 } ]
        ) ]
      end

      before do
        allow(Rails.application.credentials).to receive(:gemini_api_key).and_return("fake-key")
        allow_any_instance_of(Pdf::GeminiExtractor).to receive(:extract).and_return(gemini_results)
      end

      it "returns an array of results" do
        results = described_class.new(source).call
        expect(results).to be_an(Array)
        expect(results.first.invoice_number).to eq("F-001")
      end
    end

    context "when the PDF contains multiple invoices" do
      let(:gemini_results) do
        [
          PdfExtractionResult.new(invoice_number: "F-001", invoice_date: Date.new(2024, 1, 1),
                                  issuer_name: "Acme SL", issuer_nif: "B12345678",
                                  lines: [ { iva_rate: 21, base_imponible: 100.0, iva_amount: 21.0 } ]),
          PdfExtractionResult.new(invoice_number: "F-002", invoice_date: Date.new(2024, 1, 1),
                                  issuer_name: "Beta SL", issuer_nif: "A87654321",
                                  lines: [ { iva_rate: 10, base_imponible: 50.0, iva_amount: 5.0 } ])
        ]
      end

      before do
        allow(Rails.application.credentials).to receive(:gemini_api_key).and_return("fake-key")
        allow_any_instance_of(Pdf::GeminiExtractor).to receive(:extract).and_return(gemini_results)
      end

      it "returns all invoices found" do
        results = described_class.new(source).call
        expect(results.length).to eq(2)
        expect(results.map(&:invoice_number)).to eq([ "F-001", "F-002" ])
      end
    end

    context "when Gemini returns nothing but Groq returns a result" do
      let(:groq_results) do
        [ PdfExtractionResult.new(
          invoice_number: "G-001",
          invoice_date:   Date.new(2024, 2, 1),
          issuer_name:    "Groq SL",
          issuer_nif:     "B11111111",
          lines:          [ { iva_rate: 21, base_imponible: 200.0, iva_amount: 42.0 } ]
        ) ]
      end

      before do
        allow(Rails.application.credentials).to receive(:gemini_api_key).and_return("fake-key")
        allow_any_instance_of(Pdf::GeminiExtractor).to receive(:extract).and_return([])
        allow_any_instance_of(Pdf::GroqExtractor).to receive(:extract).and_return(groq_results)
      end

      it "uses Groq before heuristics" do
        results = described_class.new(source).call
        expect(results.first.invoice_number).to eq("G-001")
      end
    end

    context "when no Gemini or Groq API key is configured" do
      around do |example|
        was_groq = ENV.fetch("GROQ_API_KEY", nil)
        ENV.delete("GROQ_API_KEY")
        example.run
      ensure
        ENV["GROQ_API_KEY"] = was_groq if was_groq
      end

      before do
        allow(Rails.application.credentials).to receive(:gemini_api_key).and_return(nil)
        allow(Rails.application.credentials).to receive(:groq_api_key).and_return(nil)
      end

      it "falls back to heuristics (empty when text does not match patterns)" do
        results = described_class.new(source).call
        expect(results).to eq([])
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow(Rails.application.credentials).to receive(:gemini_api_key).and_return("fake-key")
        allow_any_instance_of(Pdf::GeminiExtractor).to receive(:extract).and_raise(RuntimeError, "boom")
      end

      it "raises ParseError" do
        expect { described_class.new(source).call }.to raise_error(ParsePdfInvoice::ParseError)
      end
    end
  end
end
