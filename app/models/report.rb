class Report < ApplicationRecord
  include AASM

  # Trigger the processing after commit
  after_commit :enqueue_processing, on: :create

  belongs_to :candidate
  has_many :checks, dependent: :destroy
  has_many :webhook_deliveries, dependent: :destroy

  validates :idempotency_key, presence: true, uniqueness: true
  validates :status, presence: true

  aasm column: "status" do
    state :pending, initial: true
    state :processing
    state :completed
    state :failed

    event :start_processing do
      transitions from: :pending, to: :processing
    end

    event :complete do
      transitions from: :processing, to: :completed,
                  guard: :all_checks_completed?
      after do
        update(completed_at: Time.current)
        trigger_webhooks
      end
    end

    event :mark_failed do
      transitions from: [ :pending, :processing ], to: :failed
    end
  end

  def all_checks_completed?
    checks.where.not(status: "completed").none?
  end

  def trigger_webhooks
    webhook_deliveries.pending.find_each do |delivery|
      WebhookDeliveryJob.perform_later(delivery.id)
    end
  end

  def enqueue_processing
    ProcessReportJob.perform_later(id)
  end
end
