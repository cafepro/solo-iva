require "rails_helper"

RSpec.describe ParseInvoiceDocument do
  let(:png) do
    Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )
  end

  context "with a PDF" do
    let(:bytes) { "%PDF-1.4 fake" }

    it "delegates to ParsePdfInvoice" do
      fake = [ instance_double(PdfExtractionResult, invoice_number: "X") ]
      pdf_parser = instance_double(ParsePdfInvoice, call: fake)
      allow(ParsePdfInvoice).to receive(:new).and_return(pdf_parser)

      results = described_class.new(StringIO.new(bytes), filename: "doc.pdf").call
      expect(results).to eq(fake)
      expect(ParsePdfInvoice).to have_received(:new).with(instance_of(StringIO))
    end
  end

  context "with an image" do
    it "delegates to ParseInvoiceImage" do
      fake = [ instance_double(PdfExtractionResult, invoice_number: "Y") ]
      img_parser = instance_double(ParseInvoiceImage, call: fake)
      allow(ParseInvoiceImage).to receive(:new).with(png, filename: "foto.jpg").and_return(img_parser)

      results = described_class.new(StringIO.new(png), filename: "foto.jpg").call
      expect(results).to eq(fake)
    end
  end

  context "with unsupported data" do
    it "raises ParsePdfInvoice::ParseError" do
      expect do
        described_class.new(StringIO.new("x" * 64), filename: "unknown.xyz").call
      end.to raise_error(ParsePdfInvoice::ParseError, /Formato no reconocido/)
    end
  end
end
