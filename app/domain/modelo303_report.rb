# Value object representing a Modelo 303 quarterly VAT report.
# Casillas alineadas con instrucciones AEAT ejercicio 2026 (régimen general simplificado en app).
# Lines must respond to #iva_rate, #base_imponible, and #iva_amount.
class Modelo303Report
  # Orden del formulario: 4 % → 01–03, 10 % → 04–06, 21 % → 07–09, 0 % → 150–152
  DEVENGADO_RATES = [
    { rate: 4,  base: :casilla_01, cuota: :casilla_03 },
    { rate: 10, base: :casilla_04, cuota: :casilla_06 },
    { rate: 21, base: :casilla_07, cuota: :casilla_09 }
  ].freeze

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

    DEVENGADO_RATES.each do |cfg|
      r = cfg[:rate]
      report[cfg[:base]]  = base_devengada(r)
      report[cfg[:cuota]] = cuota_devengada(r)
    end

    report[:casilla_150] = base_devengada(0)
    report[:casilla_152] = cuota_devengada(0)

    cuota_devengado_total = DEVENGADO_RATES.sum { |c| report[c[:cuota]] } + report[:casilla_152]
    cuota_devengado_total = cuota_devengado_total.round(2)

    iva_deducible  = sum_iva(@received).round(2)
    base_deducible = sum_base(@received).round(2)

    report[:casilla_27] = cuota_devengado_total
    report[:casilla_28] = base_deducible
    report[:casilla_29] = iva_deducible
    report[:casilla_45] = iva_deducible
    report[:casilla_46] = (cuota_devengado_total - iva_deducible).round(2)
    report[:casilla_64] = report[:casilla_46]

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
