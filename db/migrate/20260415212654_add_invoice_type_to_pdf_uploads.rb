class AddInvoiceTypeToPdfUploads < ActiveRecord::Migration[8.1]
  def change
    # Alineado con Invoice: emitida: 0, recibida: 1 — histórico = recibidas.
    add_column :pdf_uploads, :invoice_type, :integer, null: false, default: 1
  end
end
