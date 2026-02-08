FactoryBot.define do
  factory :webhook_delivery do
    report
    url { 'https://example.com/webhooks' }
    payload { nil }
    status { 'pending' }
    attempts { 0 }

    trait :delivered do
      status { 'delivered' }
      payload { { report_id: 1, status: 'completed' } }
    end

    trait :failed do
      status { 'failed' }
      attempts { 5 }
    end
  end
end
