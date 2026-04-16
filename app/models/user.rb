class User < ApplicationRecord
  include UserAiApiKeys

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  has_many :invoices, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :service_templates, dependent: :destroy
  has_many :pdf_uploads, dependent: :destroy
  has_many :invoice_upload_stashes, dependent: :delete_all

  validates :invoice_number_digit_count,
            numericality: { only_integer: true, greater_than: 0, less_than: 13 }
  validates :invoice_number_next,
            numericality: { only_integer: true, greater_than: 0 }

  # Atributos de emisor para nuevas facturas emitidas (rellenar desde "Datos de facturación").
  def default_issuer_attributes_for_invoice
    {
      issuer_name: billing_display_name.presence || email&.split("@")&.first&.humanize,
      issuer_nif:  billing_nif
    }
  end

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

  def google_drive_issued_invoices_folder_name
    google_drive_issued_folder_name.presence || "Emitidas"
  end

  # Segments before year/month, e.g. ["Facturas", "Recibidas"].
  def google_drive_received_invoice_path_prefix_segments
    [ google_drive_parent_folder_name, google_drive_received_invoices_folder_name ]
  end

  # e.g. ["Facturas", "Emitidas"]
  def google_drive_issued_invoice_path_prefix_segments
    [ google_drive_parent_folder_name, google_drive_issued_invoices_folder_name ]
  end
end
