class FixDecimalPrecisionOnInvoiceLines < ActiveRecord::Migration[8.1]
  def change
    change_column :invoice_lines, :base_imponible, :decimal, precision: 10, scale: 2
    change_column :invoice_lines, :iva_amount,     :decimal, precision: 10, scale: 2
    change_column :invoice_lines, :iva_rate,       :decimal, precision: 5,  scale: 2
  end
end
