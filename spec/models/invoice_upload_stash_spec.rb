require "rails_helper"

RSpec.describe InvoiceUploadStash do
  let(:user) { create(:user) }

  describe ".store!" do
    it "returns a token and persists bytes" do
      token = described_class.store!(user: user, file_data: "abc".b, filename: "f.pdf")
      expect(token).to be_present
      row = described_class.find_by!(token: token)
      expect(row.file_data).to eq("abc".b)
      expect(row.filename).to eq("f.pdf")
    end

    it "replaces previous stashes for the same user" do
      t1 = described_class.store!(user: user, file_data: "a".b, filename: "a.pdf")
      t2 = described_class.store!(user: user, file_data: "b".b, filename: "b.pdf")
      expect(described_class.where(user: user).count).to eq(1)
      expect(described_class.find_by(token: t1)).to be_nil
      expect(described_class.find_by!(token: t2).filename).to eq("b.pdf")
    end
  end

  describe ".fetch" do
    it "returns nil for unknown token" do
      expect(described_class.fetch(user, "nope")).to be_nil
    end

    it "returns data for matching user and token" do
      token = described_class.store!(user: user, file_data: "x".b, filename: "n.pdf")
      data = described_class.fetch(user, token)
      expect(data[:data]).to eq("x".b)
      expect(data[:filename]).to eq("n.pdf")
    end
  end

  describe ".delete_by_token!" do
    it "removes the row" do
      token = described_class.store!(user: user, file_data: "z".b, filename: "z.pdf")
      described_class.delete_by_token!(user, token)
      expect(described_class.where(token: token)).not_to exist
    end
  end
end
