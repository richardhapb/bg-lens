class ProcessReportJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(report_id)
    report = Report.find(report_id)
    return unless report.pending?

    report.start_processing!

    # Process each check in sequence
    report.checks.each do |check|
      ProcessCheckJob.perform_now(check.id)
    end

    # Reload and check if all complete
    report.reload
    report.complete! if report.all_checks_completed?
  rescue AASM::InvalidTransition => e
    Rails.logger.warn "Report #{report_id} state transition failed: #{e.message}"
  end
end
