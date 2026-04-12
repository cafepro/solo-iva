class AddGoogleDriveIssuedFolderToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_drive_issued_folder_name, :string
  end
end
