class Invoice < ApplicationRecord
  belongs_to :user
  has_many :invoice_lines, dependent: :destroy
  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  enum :invoice_type, { emitida: 0, recibida: 1 }

  validates :invoice_type, :invoice_date, presence: true
  validates :invoice_number, presence: true

  def quarter
    ((invoice_date.month - 1) / 3) + 1
  end

  def year
    invoice_date.year
  end

  def total_base
    invoice_lines.sum(&:base_imponible)
  end

  def total_iva
    invoice_lines.sum(&:iva_amount)
  end

  def total
    total_base + total_iva
  end
end
