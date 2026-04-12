class PdfUpload < ApplicationRecord
  belongs_to :user
  has_many :invoices, dependent: :nullify

  enum :status, { pending: "pending", processing: "processing", done: "done", failed: "failed" },
       default: "pending"

  validates :filename, :file_data, presence: true
end
