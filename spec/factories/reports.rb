FactoryBot.define do
  factory :report do
    candidate
    status { 'pending' }
    sequence(:idempotency_key) { |n| "idempotency-key-#{n}" }
    completed_at { nil }

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :with_checks do
      after(:create) do |report|
        create(:check, :criminal, report: report)
        create(:check, :employment, report: report)
      end
    end
  end
end
