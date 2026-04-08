require "rails_helper"

RSpec.describe InvoiceFileKind do
  describe ".from_bytes_and_filename" do
    it "detects PDF by magic bytes" do
      expect(described_class.from_bytes_and_filename("%PDF-1.4\n", "x.pdf")).to eq(:pdf)
    end

    it "detects PNG by magic bytes" do
      png = Base64.decode64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
      )
      expect(described_class.from_bytes_and_filename(png, "scan.png")).to eq(:image)
    end

    it "returns nil for unknown binary" do
      expect(described_class.from_bytes_and_filename("not a pdf" * 10, "x.bin")).to be_nil
    end
  end

  describe ".vision_mime_for" do
    let(:png) do
      Base64.decode64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
      )
    end

    it "returns image/png for a PNG file" do
      expect(described_class.vision_mime_for(png, "f.png")).to eq("image/png")
    end
  end
end
