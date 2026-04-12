# Temporary copy of a file uploaded from the invoice form (single-file flow) until the invoice is saved.
# Bytes are then copied onto Invoice#source_file_data and this row is deleted.
class InvoiceUploadStash < ApplicationRecord
  belongs_to :user

  validates :token, :filename, :file_data, presence: true

  class << self
    def store!(user:, file_data:, filename:)
      user.invoice_upload_stashes.delete_all
      create!(
        user:      user,
        token:     SecureRandom.urlsafe_base64(32),
        file_data: file_data.to_s.b,
        filename:  filename.to_s
      ).token
    end

    def fetch(user, token)
      return nil if token.blank?

      row = where(user_id: user.id, token: token).first
      return nil unless row

      { data: row.file_data, filename: row.filename }
    end

    def delete_by_token!(user, token)
      return if token.blank?

      where(user_id: user.id, token: token).delete_all
    end
  end
end
