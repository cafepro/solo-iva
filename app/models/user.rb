class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :invoices, dependent: :destroy
  has_many :pdf_uploads, dependent: :destroy
  has_many :invoice_upload_stashes, dependent: :delete_all

  def google_drive_ready?
    google_drive_refresh_token.present? && google_drive_sync_enabled?
  end

  # First folder under "My Drive" (default: Facturas).
  def google_drive_parent_folder_name
    google_drive_folder_name.presence || "Facturas"
  end

  # Subfolder for received invoices inside the parent (default: Recibidas).
  def google_drive_received_invoices_folder_name
    google_drive_received_folder_name.presence || "Recibidas"
  end

  # Segments before year/month, e.g. ["Facturas", "Recibidas"].
  def google_drive_received_invoice_path_prefix_segments
    [ google_drive_parent_folder_name, google_drive_received_invoices_folder_name ]
  end
end
