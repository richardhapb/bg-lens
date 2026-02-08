class WebhookDelivery < ApplicationRecord
  belongs_to :report

  validates :url, presence: true
  validates :status, inclusion: { in: %w[pending delivered failed] }

  scope :pending, -> { where(status: "pending") }
end
