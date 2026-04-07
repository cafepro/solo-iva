# Calculates invoice totals from a collection of line objects.
# Lines must respond to #base_imponible and #iva_amount.
# Intentionally decoupled from ActiveRecord — works with any duck-typed collection.
class InvoiceTotals
  attr_reader :base, :iva, :total

  def initialize(lines)
    @base  = lines.sum { |l| l.base_imponible.to_f }.round(2)
    @iva   = lines.sum { |l| l.iva_amount.to_f }.round(2)
    @total = (@base + @iva).round(2)
  end
end
