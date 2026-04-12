class ClientsBillingAndIssuedInvoiceFields < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :nif
      t.string :address_line
      t.string :postal_code
      t.string :city
      t.string :province
      t.string :country, default: "España", null: false
    end

    add_index :clients, [ :user_id, :name ]

    add_reference :invoices, :client, foreign_key: true

    add_column :invoices, :recipient_address_line, :string
    add_column :invoices, :recipient_postal_code, :string
    add_column :invoices, :recipient_city, :string
    add_column :invoices, :recipient_province, :string
    add_column :invoices, :recipient_country, :string
    add_column :invoices, :service_period_start, :date
    add_column :invoices, :service_period_end, :date
    add_column :invoices, :payment_signed_note, :string

    add_column :invoice_lines, :description, :string

    change_table :users, bulk: true do |t|
      t.string :billing_display_name
      t.string :billing_nif
      t.string :billing_address_line
      t.string :billing_postal_code
      t.string :billing_city
      t.string :billing_province
      t.string :billing_country
      t.string :billing_phone
      t.string :billing_email
      t.string :paypal_email
      t.string :iban
      t.text :payment_methods_note

      t.string :invoice_number_prefix, default: "F", null: false
      t.integer :invoice_number_digit_count, default: 3, null: false
      t.integer :invoice_number_next, default: 1, null: false
    end
  end
end
