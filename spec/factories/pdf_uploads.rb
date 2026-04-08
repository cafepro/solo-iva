FactoryBot.define do
  factory :pdf_upload do
    association :user
    filename  { "factura.pdf" }
    file_data { "%PDF-1.4 fake content".b }
    status    { "pending" }
  end
end
