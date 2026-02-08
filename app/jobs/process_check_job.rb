class ProcessCheckJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(check_id)
    check = Check.find(check_id)
    return if check.status == 'completed'

    check.process!
  rescue StandardError => e
    Rails.logger.error "Check #{check_id} failed: #{e.message}"
    raise
  end
end
