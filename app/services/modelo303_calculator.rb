class Modelo303Calculator
  attr_reader :user, :year, :quarter

  def initialize(user:, year:, quarter:)
    @user    = user
    @year    = year
    @quarter = quarter
  end

  def calculate
    {
      # IVA Devengado (facturas emitidas)
      casilla_01: base_devengada(21),
      casilla_02: cuota_devengada(21),
      casilla_03: base_devengada(10),
      casilla_04: cuota_devengada(10),
      casilla_05: base_devengada(4),
      casilla_06: cuota_devengada(4),
      casilla_46: total_iva_devengado,
      # IVA Deducible (facturas recibidas)
      casilla_28: total_base_deducible,
      casilla_29: total_iva_deducible,
      casilla_47: total_iva_deducible,
      # Resultado
      casilla_64: resultado
    }
  end

  private

  def emitidas_lines
    @emitidas_lines ||= lines_for(:emitida)
  end

  def recibidas_lines
    @recibidas_lines ||= lines_for(:recibida)
  end

  def lines_for(invoice_type)
    InvoiceLine
      .joins(:invoice)
      .where(
        invoices: {
          user_id:      user.id,
          invoice_type: Invoice.invoice_types[invoice_type]
        }
      )
      .where("EXTRACT(year FROM invoices.invoice_date) = ?", year)
      .where("EXTRACT(quarter FROM invoices.invoice_date) = ?", quarter)
  end

  def base_devengada(rate)
    emitidas_lines.where(iva_rate: rate).sum(:base_imponible).to_f.round(2)
  end

  def cuota_devengada(rate)
    emitidas_lines.where(iva_rate: rate).sum(:iva_amount).to_f.round(2)
  end

  def total_iva_devengado
    emitidas_lines.sum(:iva_amount).to_f.round(2)
  end

  def total_base_deducible
    recibidas_lines.sum(:base_imponible).to_f.round(2)
  end

  def total_iva_deducible
    recibidas_lines.sum(:iva_amount).to_f.round(2)
  end

  def resultado
    (total_iva_devengado - total_iva_deducible).round(2)
  end
end
