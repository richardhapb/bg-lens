require 'rails_helper'

RSpec.describe CreateBackgroundCheckService do
  let(:candidate_params) do
    {
      name: 'John Doe',
      ssn: '123-45-6789',
      dob: '1990-01-01',
      email: 'john@example.com'
    }
  end

  describe '#call' do
    it 'creates a report with checks' do
      service = described_class.new(
        candidate_params: candidate_params,
        check_types: %w[criminal employment],
        idempotency_key: 'test-key-123'
      )

      result = service.call

      expect(result.success?).to be true
      expect(result.data).to be_a(Report)
      expect(result.data.checks.count).to eq 2
      expect(result.data.idempotency_key).to eq 'test-key-123'
    end

    it 'creates a candidate if one does not exist' do
      service = described_class.new(
        candidate_params: candidate_params,
        check_types: %w[criminal],
        idempotency_key: 'new-candidate-key'
      )

      expect { service.call }.to change(Candidate, :count).by(1)
    end

    it 'reuses existing candidate by SSN' do
      existing = create(:candidate, ssn: '123-45-6789')

      service = described_class.new(
        candidate_params: candidate_params,
        check_types: %w[criminal],
        idempotency_key: 'existing-candidate-key'
      )

      expect { service.call }.not_to change(Candidate, :count)
      expect(service.call.data.candidate).to eq existing
    end

    it 'returns existing report for duplicate idempotency key' do
      key = 'duplicate-key'

      first_result = described_class.new(
        candidate_params: candidate_params,
        check_types: %w[criminal],
        idempotency_key: key
      ).call

      second_result = described_class.new(
        candidate_params: candidate_params.merge(name: 'Different Name'),
        check_types: %w[employment education],
        idempotency_key: key
      ).call

      expect(second_result.data.id).to eq first_result.data.id
      expect(second_result.data.checks.count).to eq 1
    end

    it 'enqueues ProcessReportJob' do
      service = described_class.new(
        candidate_params: candidate_params,
        check_types: %w[criminal],
        idempotency_key: 'job-test-key'
      )

      expect {
        service.call
      }.to have_enqueued_job(ProcessReportJob)
    end

    it 'creates webhook delivery when webhook_url is provided' do
      service = described_class.new(
        candidate_params: candidate_params,
        check_types: %w[criminal],
        idempotency_key: 'webhook-test-key',
        webhook_url: 'https://example.com/webhooks'
      )

      result = service.call

      expect(result.data.webhook_deliveries.count).to eq 1
      expect(result.data.webhook_deliveries.first.url).to eq 'https://example.com/webhooks'
    end

    it 'does not create webhook delivery when webhook_url is not provided' do
      service = described_class.new(
        candidate_params: candidate_params,
        check_types: %w[criminal],
        idempotency_key: 'no-webhook-key'
      )

      result = service.call

      expect(result.data.webhook_deliveries.count).to eq 0
    end

    context 'with invalid candidate params' do
      it 'returns failure result' do
        service = described_class.new(
          candidate_params: { name: '', ssn: '', dob: '', email: '' },
          check_types: %w[criminal],
          idempotency_key: 'invalid-candidate-key'
        )

        result = service.call

        expect(result.failure?).to be true
        expect(result.errors).not_to be_empty
      end
    end
  end
end
