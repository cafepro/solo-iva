class InvoicePdfUploadAndDriveSubfolder < ActiveRecord::Migration[8.1]
  def up
    add_reference :invoices, :pdf_upload, foreign_key: true
    add_column :users, :google_drive_received_folder_name, :string

    say_with_time "split legacy google_drive_folder_name containing /" do
      User.where.not(google_drive_folder_name: nil).find_each do |u|
        name = u.google_drive_folder_name.to_s.strip
        next if name.blank?

        if name.include?("/")
          parent, child = name.split("/", 2).map(&:strip)
          User.where(id: u.id).update_all(
            google_drive_folder_name:          parent.presence,
            google_drive_received_folder_name:   child.presence
          )
        elsif name.downcase == "facturas recibidas"
          User.where(id: u.id).update_all(
            google_drive_folder_name:          "Facturas",
            google_drive_received_folder_name: "Recibidas"
          )
        end
      end
    end
  end

  def down
    remove_reference :invoices, :pdf_upload, foreign_key: true
    remove_column :users, :google_drive_received_folder_name
  end
end
