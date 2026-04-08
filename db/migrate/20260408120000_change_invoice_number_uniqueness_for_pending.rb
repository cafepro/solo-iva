class ChangeInvoiceNumberUniquenessForPending < ActiveRecord::Migration[8.1]
  def change
    remove_index :invoices, name: "index_invoices_on_user_type_number"

    add_index :invoices,
              %i[user_id invoice_type invoice_number],
              unique: true,
              where: "status = 'confirmed'",
              name: "index_invoices_confirmed_user_type_number"
  end
end
