class AddGoogleDriveFields < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.text :google_drive_refresh_token
      t.boolean :google_drive_sync_enabled, null: false, default: false
      t.string :google_drive_folder_name
    end

    change_table :invoices, bulk: true do |t|
      t.string :google_drive_file_id
      t.datetime :google_drive_synced_at
    end
  end
end
