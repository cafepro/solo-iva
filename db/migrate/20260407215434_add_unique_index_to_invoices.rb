class AddUniqueIndexToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_index :invoices, %i[user_id invoice_type invoice_number], unique: true,
              name: "index_invoices_on_user_type_number"
  end
end
