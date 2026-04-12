class Client < ApplicationRecord
  belongs_to :user
  has_many :invoices, dependent: :nullify

  validates :name, presence: true
end
