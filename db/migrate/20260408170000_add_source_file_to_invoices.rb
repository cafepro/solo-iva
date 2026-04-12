class AddSourceFileToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :source_file_data, :binary
    add_column :invoices, :source_filename, :string
  end
end
