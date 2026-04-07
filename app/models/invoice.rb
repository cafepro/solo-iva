class Invoice < ApplicationRecord
  belongs_to :user
  has_many :invoice_lines, dependent: :destroy
  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  enum :invoice_type, { emitida: 0, recibida: 1 }

  validates :invoice_type, :invoice_date, :invoice_number, presence: true

  def totals
    InvoiceTotals.new(invoice_lines)
  end

  def total_base = totals.base
  def total_iva  = totals.iva
  def total      = totals.total

  def quarter
    QuarterCalculator.quarter_for(invoice_date)
  end

  def year
    QuarterCalculator.year_for(invoice_date)
  end
end
