class CreateInvoiceLines < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_lines do |t|
      t.references :invoice, null: false, foreign_key: true
      t.decimal :iva_rate
      t.decimal :base_imponible
      t.decimal :iva_amount

      t.timestamps
    end
  end
end
