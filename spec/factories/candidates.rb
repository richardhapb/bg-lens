FactoryBot.define do
  factory :candidate do
    sequence(:name) { |n| "Candidate #{n}" }
    sequence(:ssn) { |n| "#{n.to_s.rjust(3, '0')}-45-6789" }
    dob { 30.years.ago.to_date }
    sequence(:email) { |n| "candidate#{n}@example.com" }
  end
end
