class CriminalCheckStrategy
  def execute(candidate)
    # In a real implementation, this would call an external API
    # For now, we simulate a response
    simulate_api_delay

    {
      records_found: rand(0..3),
      offenses: generate_mock_offenses,
      checked_at: Time.current.iso8601
    }
  end

  private

  def simulate_api_delay
    sleep(rand(0.5..2.0))
  end

  def generate_mock_offenses
    return [] if rand > 0.3

    [ {
      type: %w[misdemeanor felony infraction].sample,
      date: rand(1..10).years.ago.to_date.iso8601,
      jurisdiction: [ "San Francisco County", "Los Angeles County", "New York County" ].sample
    } ]
  end
end
