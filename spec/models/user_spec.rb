require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:invoices).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:password) }
  end
end
