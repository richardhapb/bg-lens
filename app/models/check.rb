class Check < ApplicationRecord
  belongs_to :report

  validates :check_type, inclusion: { in: %w[criminal employment education] }
  validates :status, inclusion: { in: %w[pending processing completed failed] }

  def process!
    update!(status: "processing")
    strategy = check_strategy
    result = strategy.execute(report.candidate)

    update!(
      status: "completed",
      result: result,
      provider_response: result
    )
  rescue StandardError => e
    update!(status: "failed", result: { error: e.message })
    raise
  end

  private

  def check_strategy
    case check_type
    when "criminal" then CriminalCheckStrategy.new
    when "employment" then EmploymentCheckStrategy.new
    when "education" then EducationCheckStrategy.new
    else
      raise "Unknown check type: #{check_type}"
    end
  end
end
