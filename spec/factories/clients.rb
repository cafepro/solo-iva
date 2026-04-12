FactoryBot.define do
  factory :client do
    association :user
    name  { "Cliente Demo SL" }
    nif   { "B11111111" }
    address_line { "Calle Mayor 1" }
    postal_code  { "28001" }
    city         { "Madrid" }
    province     { "Madrid" }
    country      { "España" }
  end
end
