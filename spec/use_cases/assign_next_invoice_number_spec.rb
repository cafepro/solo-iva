require "rails_helper"

RSpec.describe AssignNextInvoiceNumber do
  let(:user) do
    create(
      :user,
      invoice_number_prefix:       "F2026",
      invoice_number_digit_count:  3,
      invoice_number_next:         15
    )
  end

  describe "#preview" do
    it "formats the next number without incrementing" do
      expect(described_class.new(user).preview).to eq("F2026015")
      expect(user.reload.invoice_number_next).to eq(15)
    end

    it "usa el contador persistido aunque el usuario tenga cambios sin guardar en memoria" do
      user.assign_attributes(invoice_number_next: 99)
      expect(described_class.new(user).preview).to eq("F2026015")
      expect(user.reload.invoice_number_next).to eq(15)
    end
  end

  describe "#consume!" do
    it "returns formatted number and increments" do
      str = described_class.new(user).consume!
      expect(str).to eq("F2026015")
      expect(user.reload.invoice_number_next).to eq(16)
    end
  end
end
