require "rails_helper"

RSpec.describe ServiceTemplate, type: :model do
  subject { build(:service_template) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_inclusion_of(:billing_period).in_array(ServiceTemplate::BILLING_PERIODS) }
  it { is_expected.to validate_inclusion_of(:default_iva_rate).in_array(ServiceTemplate::VALID_IVA_RATES) }

  it "rechaza base negativa" do
    subject.default_base_imponible = -1
    expect(subject).not_to be_valid
  end
end
