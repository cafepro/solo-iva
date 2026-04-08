require "rails_helper"

RSpec.describe Pdf::InvoiceExtractionResponseParser do
  let(:json) do
    {
      "invoices" => [ {
        "invoice_number" => "F-001",
        "invoice_date"   => "2024-01-01",
        "issuer_name"    => "Acme SL",
        "issuer_nif"     => "B12345678",
        "lines"          => [ { "iva_rate" => 21, "base_imponible" => 100.0, "iva_amount" => 21.0 } ]
      } ]
    }
  end

  describe ".parse" do
    it "parses raw JSON" do
      results = described_class.parse(JSON.generate(json))
      expect(results.length).to eq(1)
      expect(results.first.invoice_number).to eq("F-001")
    end

    it "strips markdown fences" do
      raw = "```json\n#{JSON.generate(json)}\n```"
      results = described_class.parse(raw)
      expect(results.length).to eq(1)
    end

    it "extracts JSON when the model prepends prose (common with some LLMs)" do
      raw = <<~TEXT
        Here is my analysis of the document.

        {"invoices":[{"invoice_number":"F-001","invoice_date":"2024-01-01","issuer_name":"Acme SL","issuer_nif":"B12345678","lines":[{"iva_rate":21,"base_imponible":100.0,"iva_amount":21.0}]}]}
      TEXT
      results = described_class.parse(raw)
      expect(results.length).to eq(1)
      expect(results.first.invoice_number).to eq("F-001")
    end

    it "returns empty array for unparseable content" do
      expect(described_class.parse("not json at all")).to eq([])
    end

    it "parses the first balanced JSON object when multiple closing braces exist in nested arrays" do
      raw = <<~TXT
        Intro paragraph without braces.

        {"invoices":[{"invoice_number":"A","invoice_date":null,"issuer_name":null,"issuer_nif":null,"lines":[{"iva_rate":21,"base_imponible":1.0,"iva_amount":0.21}]},{"invoice_number":"B","invoice_date":null,"issuer_name":null,"issuer_nif":null,"lines":[]}]}
      TXT
      results = described_class.parse(raw)
      expect(results.map(&:invoice_number)).to eq(%w[A B])
    end
  end
end
