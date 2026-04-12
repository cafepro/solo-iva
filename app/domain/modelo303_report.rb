# Value object representing a Modelo 303 quarterly VAT report.
# Casillas alineadas con instrucciones AEAT ejercicio 2026 (régimen general simplificado en app).
# Lines must respond to #iva_rate, #base_imponible, and #iva_amount.
#
# Las cuotas (devengado y deducible) se calculan como en el programa de la AEAT: base acumulada
# por tipo impositivo × tipo / 100, redondeo a céntimos (medio arriba). No se suman las cuotas
# almacenadas en cada línea, para evitar diferencias de céntimos frente al modelo en línea.
require "bigdecimal"

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

    base_deducible = sum_base(@received).round(2)
    iva_deducible  = cuota_deducible_total.round(2)

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
    return 0.0 if rate.to_i.zero?

    base = base_devengada(rate)
    cuota_from_base_and_rate(base, rate)
  end

  def lines_at_rate(lines, rate)
    lines.select { |l| l.iva_rate.to_i == rate }
  end

  def sum_base(lines)
    lines.sum { |l| l.base_imponible.to_f }.round(2)
  end

  # Cuota deducible total: por cada tipo impositivo, base agregada × tipo (misma lógica que devengado).
  def cuota_deducible_total
    @received.group_by { |l| l.iva_rate.to_i }.sum do |rate, lines|
      base = lines.sum { |l| l.base_imponible.to_f }.round(2)
      cuota_from_base_and_rate(base, rate)
    end
  end

  def cuota_from_base_and_rate(base, rate)
    return 0.0 if base.zero? || rate.to_i.zero?

    b = BigDecimal(base.to_s).round(2, :half_up)
    r = BigDecimal(rate.to_s)
    (b * r / 100).round(2, :half_up).to_f
  end
end
