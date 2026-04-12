class Client < ApplicationRecord
  belongs_to :user
  has_many :invoices, dependent: :nullify

  validates :name, presence: true

  # Campos del receptor en factura emitida (servidor + JSON para el formulario).
  def attributes_for_invoice_recipient
    {
      recipient_name:           name,
      recipient_nif:            nif,
      recipient_address_line:   address_line,
      recipient_postal_code:    postal_code,
      recipient_city:           city,
      recipient_province:       province,
      recipient_country:        country.presence || "España"
    }.transform_values { |v| v.nil? ? "" : v.to_s }
  end
end
