class ReportSerializer
  def initialize(report)
    @report = report
  end

  def as_json
    {
      id: @report.id,
      status: @report.status,
      idempotency_key: @report.idempotency_key,
      candidate: {
        id: @report.candidate.id,
        name: @report.candidate.name,
        email: @report.candidate.email
      },
      checks: @report.checks.map { |check| serialize_check(check) },
      completed_at: @report.completed_at&.iso8601,
      created_at: @report.created_at.iso8601,
      updated_at: @report.updated_at.iso8601
    }
  end

  private

  def serialize_check(check)
    {
      id: check.id,
      type: check.check_type,
      status: check.status,
      result: check.result,
      created_at: check.created_at.iso8601,
      updated_at: check.updated_at.iso8601
    }
  end
end
