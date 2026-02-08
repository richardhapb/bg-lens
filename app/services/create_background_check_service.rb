class CreateBackgroundCheckService
  attr_reader :candidate_params, :check_types, :idempotency_key, :webhook_url

  def initialize(candidate_params:, check_types:, idempotency_key:, webhook_url: nil)
    @candidate_params = candidate_params
    @check_types = check_types
    @idempotency_key = idempotency_key
    @webhook_url = webhook_url
  end

  def call
    # Check for existing report with same idempotency key (idempotent request)
    existing_report = Report.find_by(idempotency_key: idempotency_key)
    return Result.success(existing_report) if existing_report

    ActiveRecord::Base.transaction do
      candidate = find_or_create_candidate
      report = create_report(candidate)
      create_checks(report)
      create_webhook_delivery(report) if webhook_url.present?
      enqueue_processing(report)

      Result.success(report)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.failure(e.record.errors.full_messages)
  rescue StandardError => e
    Result.failure([e.message])
  end

  private

  def find_or_create_candidate
    Candidate.find_or_create_by!(ssn: candidate_params[:ssn]) do |c|
      c.name = candidate_params[:name]
      c.dob = candidate_params[:dob]
      c.email = candidate_params[:email]
    end
  end

  def create_report(candidate)
    Report.create!(
      candidate: candidate,
      idempotency_key: idempotency_key,
      status: 'pending'
    )
  end

  def create_checks(report)
    check_types.each do |type|
      report.checks.create!(check_type: type, status: 'pending')
    end
  end

  def create_webhook_delivery(report)
    WebhookDelivery.create!(
      report: report,
      url: webhook_url,
      status: 'pending',
      attempts: 0
    )
  end

  def enqueue_processing(report)
    ProcessReportJob.perform_later(report.id)
  end

  class Result
    attr_reader :data, :errors

    def self.success(data)
      new(success: true, data: data)
    end

    def self.failure(errors)
      new(success: false, errors: Array(errors))
    end

    def initialize(success:, data: nil, errors: nil)
      @success = success
      @data = data
      @errors = errors
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end
end
