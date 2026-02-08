class EmploymentCheckStrategy
  def execute(candidate)
    simulate_api_delay

    {
      verified: [ true, false ].sample,
      previous_employers: rand(1..5),
      discrepancies: generate_discrepancies,
      checked_at: Time.current.iso8601
    }
  end

  private

  def simulate_api_delay
    sleep(rand(1.0..3.0))
  end

  def generate_discrepancies
    return [] if rand > 0.2

    [ "Employment dates mismatch", "Title discrepancy" ].sample(1)
  end
end
