FactoryBot.define do
  factory :check do
    report
    check_type { 'criminal' }
    status { 'pending' }
    result { nil }
    provider_response { nil }

    trait :criminal do
      check_type { 'criminal' }
    end

    trait :employment do
      check_type { 'employment' }
    end

    trait :education do
      check_type { 'education' }
    end

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
      result { { records_found: 0, checked_at: Time.current.iso8601 } }
    end

    trait :failed do
      status { 'failed' }
      result { { error: 'Check failed' } }
    end
  end
end
