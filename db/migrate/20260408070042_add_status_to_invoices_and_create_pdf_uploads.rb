class AddStatusToInvoicesAndCreatePdfUploads < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :status, :string, null: false, default: "confirmed"
    add_index  :invoices, :status

    create_table :pdf_uploads do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :filename,      null: false
      t.string  :status,        null: false, default: "pending"
      t.binary  :file_data,     null: false
      t.text    :error_message
      t.timestamps
    end
  end
end
