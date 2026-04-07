class InvoiceLine < ApplicationRecord
  belongs_to :invoice

  VALID_RATES = [ 0, 4, 5, 10, 21 ].freeze

  validates :iva_rate, :base_imponible, presence: true
  validates :iva_rate, inclusion: { in: VALID_RATES }
  validates :base_imponible, numericality: true

  before_save :calculate_iva_amount

  private

  def calculate_iva_amount
    self.iva_amount = (base_imponible * iva_rate / 100.0).round(2)
  end
end
