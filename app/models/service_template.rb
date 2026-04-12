class ServiceTemplate < ApplicationRecord
  belongs_to :user

  BILLING_PERIODS = %w[day week month custom].freeze
  BILLING_PERIOD_LABELS = {
    "day"    => "Por día (fecha de factura)",
    "week"   => "Por semana (lun–dom de la fecha)",
    "month"  => "Por mes natural",
    "custom" => "Solo concepto e importe (periodo manual)"
  }.freeze
  VALID_IVA_RATES = [ 0, 4, 10, 21 ].freeze

  validates :name, presence: true
  validates :billing_period, inclusion: { in: BILLING_PERIODS }
  validates :default_iva_rate, inclusion: { in: VALID_IVA_RATES }
  validates :default_base_imponible, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def self.billing_period_select_options
    BILLING_PERIODS.map { |p| [ BILLING_PERIOD_LABELS.fetch(p), p ] }
  end

  def billing_period_label
    BILLING_PERIOD_LABELS[billing_period] || billing_period
  end
end
