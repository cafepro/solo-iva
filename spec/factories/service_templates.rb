FactoryBot.define do
  factory :service_template do
    user
    name { "Plantilla demo" }
    billing_period { "month" }
    default_description { "Servicio mensual" }
    default_base_imponible { 100.0 }
    default_iva_rate { 21 }
  end
end
