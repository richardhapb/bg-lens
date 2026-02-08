class EducationCheckStrategy
  def execute(candidate)
    simulate_api_delay

    {
      degree_verified: [ true, false ].sample,
      institution: [ "Stanford University", "MIT", "UC Berkeley", "Harvard University" ].sample,
      graduation_year: rand(2010..2023),
      checked_at: Time.current.iso8601
    }
  end

  private

  def simulate_api_delay
    sleep(rand(0.5..1.5))
  end
end
