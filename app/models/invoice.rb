class Invoice < ApplicationRecord
  belongs_to :user
  has_many :invoice_lines, dependent: :destroy
  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  enum :invoice_type, { emitida: 0, recibida: 1 }
  enum :status, { pending: "pending", confirmed: "confirmed" }, default: "confirmed"

  scope :pending_review, -> { where(status: "pending") }
  scope :for_accounting, -> { where(status: "confirmed") }

  validates :invoice_type, :invoice_date, :invoice_number, presence: true
  validate :invoice_number_unique_among_confirmed, if: :confirmed?

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

  private

  def invoice_number_unique_among_confirmed
    return if invoice_number.blank?

    scope = self.class.where(
      user_id:        user_id,
      invoice_type: invoice_type,
      invoice_number: invoice_number,
      status:         :confirmed
    )
    scope = scope.where.not(id: id) if persisted?
    return unless scope.exists?

    errors.add(:invoice_number, "ya existe una factura confirmada con este número para este tipo")
  end
end
