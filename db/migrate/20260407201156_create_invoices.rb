class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :invoice_type
      t.string :invoice_number
      t.date :invoice_date
      t.string :issuer_name
      t.string :issuer_nif
      t.string :recipient_name
      t.string :recipient_nif
      t.text :notes

      t.timestamps
    end
  end
end
