FactoryBot.define do
  factory :invoice_line do
    association :invoice
    iva_rate       { 21 }
    base_imponible { 100.00 }
    iva_amount     { 21.00 }
  end
end
