class CreateInvoiceUploadStashes < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_upload_stashes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.binary :file_data, null: false
      t.string :filename, null: false
    end

    add_index :invoice_upload_stashes, :token, unique: true
  end
end
