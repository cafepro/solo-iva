# Fetches invoice lines for a given user/year/quarter from the database
# and builds a Modelo303Report domain object.
class CalculateModelo303
  def initialize(user:, year:, quarter:)
    @user    = user
    @year    = year
    @quarter = quarter
  end

  def call
    Modelo303Report.new(
      lines_issued:   lines_for(:emitida),
      lines_received: lines_for(:recibida)
    )
  end

  private

  def lines_for(invoice_type)
    InvoiceLine
      .joins(:invoice)
      .where(
        invoices: {
          user_id:      @user.id,
          invoice_type: Invoice.invoice_types[invoice_type]
        }
      )
      .where("EXTRACT(year FROM invoices.invoice_date) = ?", @year)
      .where("EXTRACT(quarter FROM invoices.invoice_date) = ?", @quarter)
  end
end
