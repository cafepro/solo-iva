require "rails_helper"

RSpec.describe Pdf::RegexExtractor do
  def extractor_with_text(text)
    instance = described_class.new(StringIO.new(""))
    allow(instance).to receive(:read_text).and_return(text)
    instance
  end

  describe "#extract" do
    context "when the PDF contains parseable data" do
      let(:invoice_text) do
        <<~TEXT
          Factura nº: F-2024-001
          Fecha: 15/03/2024
          NIF: B12345678
          Acme SL

          21% 1.000,00
        TEXT
      end

      subject(:result) { extractor_with_text(invoice_text).extract }

      it "returns a PdfExtractionResult" do
        expect(result).to be_a(PdfExtractionResult)
      end

      it "extracts the invoice number via labeled pattern" do
        expect(result.invoice_number).to eq("F-2024-001")
      end

      it "extracts the invoice date" do
        expect(result.invoice_date).to eq(Date.new(2024, 3, 15))
      end

      it "extracts the issuer NIF" do
        expect(result.issuer_nif).to eq("B12345678")
      end

      it "extracts IVA lines" do
        expect(result.lines).not_to be_empty
        expect(result.lines.first[:iva_rate]).to eq(21)
      end
    end

    context "when the invoice number has no label but a letter-prefixed format" do
      subject(:result) { extractor_with_text("S265022\nFecha: 01/01/2026\n21% 100,00").extract }

      it "extracts it via the alpha-numeric pattern" do
        expect(result.invoice_number).to eq("S265022")
      end
    end

    context "when the PDF has no recognizable data" do
      subject(:result) { extractor_with_text("Lorem ipsum dolor sit amet").extract }

      it "returns a result with empty lines" do
        expect(result.lines).to be_empty
      end
    end
  end

  describe "amount parsing" do
    it "parses Spanish decimal notation (comma as decimal separator)" do
      result = extractor_with_text("21% 1.500,75").extract
      line = result.lines.first
      expect(line[:base_imponible]).to eq(1500.75) if line
    end
  end
end
