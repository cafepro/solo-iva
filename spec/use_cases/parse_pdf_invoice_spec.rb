require "rails_helper"

RSpec.describe ParsePdfInvoice do
  let(:source) { StringIO.new("fake pdf content") }

  before do
    # extract_text always runs first; stub it so PDF::Reader is never called
    allow_any_instance_of(ParsePdfInvoice).to receive(:extract_text).and_return("invoice text")
  end

  describe "#call" do
    context "when regex extraction returns invoice number and lines" do
      let(:regex_result) do
        PdfExtractionResult.new(
          invoice_number: "F-001",
          invoice_date:   nil,
          issuer_name:    nil,
          issuer_nif:     nil,
          lines:          [{ iva_rate: 21, base_imponible: 100.0, iva_amount: 21.0 }]
        )
      end

      before { allow_any_instance_of(Pdf::RegexExtractor).to receive(:extract).and_return(regex_result) }

      it "returns the regex result without calling Gemini" do
        expect_any_instance_of(Pdf::GeminiExtractor).not_to receive(:extract)
        result = described_class.new(source).call
        expect(result.invoice_number).to eq("F-001")
      end
    end

    context "when regex extraction is missing invoice number or lines" do
      let(:incomplete_result) do
        PdfExtractionResult.new(invoice_number: nil, invoice_date: Date.new(2024, 1, 1),
                                issuer_name: "Acme SL", issuer_nif: "B12345678", lines: [])
      end

      let(:gemini_result) do
        PdfExtractionResult.new(
          invoice_number: "F-002",
          invoice_date:   Date.new(2024, 2, 1),
          issuer_name:    "Beta SL",
          issuer_nif:     "A11111111",
          lines:          [{ iva_rate: 10, base_imponible: 500.0, iva_amount: 50.0 }]
        )
      end

      before do
        allow_any_instance_of(Pdf::RegexExtractor).to receive(:extract).and_return(incomplete_result)
        allow(Rails.application.credentials).to receive(:gemini_api_key).and_return("fake-key")
        allow_any_instance_of(Pdf::GeminiExtractor).to receive(:extract).and_return(gemini_result)
      end

      it "falls back to Gemini extraction" do
        result = described_class.new(source).call
        expect(result.invoice_number).to eq("F-002")
      end
    end

    context "when an unexpected error occurs" do
      before { allow_any_instance_of(Pdf::RegexExtractor).to receive(:extract).and_raise(RuntimeError, "boom") }

      it "raises ParseError" do
        expect { described_class.new(source).call }.to raise_error(ParsePdfInvoice::ParseError)
      end
    end
  end
end
