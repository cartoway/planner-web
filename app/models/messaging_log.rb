class MessagingLog < ApplicationRecord
  belongs_to :customer

  validates :customer, presence: true
  validates :service, presence: true
  validates :recipient, presence: true
  validates :content, presence: true
end
