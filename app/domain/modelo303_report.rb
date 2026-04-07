# Value object representing a Modelo 303 quarterly VAT report.
# Accepts plain line structs — no ActiveRecord dependency.
# Lines must respond to #iva_rate, #base_imponible, and #iva_amount.
class Modelo303Report
  SUPPORTED_RATES = [21, 10, 4].freeze

  attr_reader :casillas

  def initialize(lines_issued:, lines_received:)
    @issued   = lines_issued
    @received = lines_received
    @casillas = build_casillas
  end

  def to_h
    @casillas
  end

  private

  def build_casillas
    report = {}

    SUPPORTED_RATES.each_with_index do |rate, i|
      base_key  = "casilla_#{format('%02d', (i * 2) + 1)}".to_sym
      quota_key = "casilla_#{format('%02d', (i * 2) + 2)}".to_sym
      report[base_key]  = base_devengada(rate)
      report[quota_key] = cuota_devengada(rate)
    end

    iva_devengado  = report.values_at(:casilla_02, :casilla_04, :casilla_06).sum.round(2)
    iva_deducible  = sum_iva(@received)
    base_deducible = sum_base(@received)

    report[:casilla_46] = iva_devengado
    report[:casilla_28] = base_deducible
    report[:casilla_29] = iva_deducible
    report[:casilla_47] = iva_deducible
    report[:casilla_64] = (iva_devengado - iva_deducible).round(2)

    report
  end

  def base_devengada(rate)
    lines_at_rate(@issued, rate).sum { |l| l.base_imponible.to_f }.round(2)
  end

  def cuota_devengada(rate)
    lines_at_rate(@issued, rate).sum { |l| l.iva_amount.to_f }.round(2)
  end

  def lines_at_rate(lines, rate)
    lines.select { |l| l.iva_rate.to_i == rate }
  end

  def sum_base(lines)
    lines.sum { |l| l.base_imponible.to_f }.round(2)
  end

  def sum_iva(lines)
    lines.sum { |l| l.iva_amount.to_f }.round(2)
  end
end
