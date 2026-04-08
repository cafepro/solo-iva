FactoryBot.define do
  factory :invoice do
    association :user
    invoice_type   { :emitida }
    invoice_number { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
    invoice_date   { Date.today }
    issuer_name    { Faker::Company.name }
    issuer_nif     { "B12345678" }
    recipient_name { Faker::Company.name }
    recipient_nif  { "A87654321" }

    trait :recibida do
      invoice_type { :recibida }
    end

    trait :pending do
      status { :pending }
    end
  end
end
