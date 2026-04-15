class AddInvoicePdfHeaderTitleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :invoice_pdf_header_title, :string
  end
end
