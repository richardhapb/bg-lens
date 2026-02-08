require 'rails_helper'

RSpec.describe 'Api::V1::BackgroundChecks', type: :request do
  describe 'POST /api/v1/background_checks' do
    let(:valid_params) do
      {
        candidate: {
          name: 'Jane Doe',
          ssn: '987-65-4321',
          dob: '1985-05-15',
          email: 'jane@example.com'
        },
        check_types: %w[criminal employment],
        webhook_url: 'https://example.com/webhooks'
      }
    end

    it 'creates a background check' do
      post '/api/v1/background_checks',
           params: valid_params,
           headers: { 'Idempotency-Key' => 'unique-key-456' }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['status']).to eq 'pending'
      expect(json['checks'].size).to eq 2
    end

    it 'returns candidate information' do
      post '/api/v1/background_checks',
           params: valid_params,
           headers: { 'Idempotency-Key' => 'candidate-info-key' }

      json = JSON.parse(response.body)
      expect(json['candidate']['name']).to eq 'Jane Doe'
      expect(json['candidate']['email']).to eq 'jane@example.com'
    end

    it 'handles idempotent requests' do
      headers = { 'Idempotency-Key' => 'same-key' }

      post '/api/v1/background_checks', params: valid_params, headers: headers
      first_id = JSON.parse(response.body)['id']

      post '/api/v1/background_checks', params: valid_params, headers: headers
      second_id = JSON.parse(response.body)['id']

      expect(first_id).to eq second_id
    end

    it 'generates idempotency key if not provided' do
      post '/api/v1/background_checks', params: valid_params

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['idempotency_key']).to be_present
    end

    it 'uses default check types when not specified' do
      params = valid_params.except(:check_types)
      post '/api/v1/background_checks',
           params: params,
           headers: { 'Idempotency-Key' => 'default-checks-key' }

      json = JSON.parse(response.body)
      expect(json['checks'].map { |c| c['type'] }).to match_array(%w[criminal employment])
    end

    context 'with invalid params' do
      it 'returns unprocessable entity for missing candidate' do
        post '/api/v1/background_checks',
             params: { check_types: %w[criminal] },
             headers: { 'Idempotency-Key' => 'missing-candidate-key' }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns unprocessable entity for invalid candidate data' do
        post '/api/v1/background_checks',
             params: { candidate: { name: '', ssn: '', dob: '', email: '' } },
             headers: { 'Idempotency-Key' => 'invalid-data-key' }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end
  end

  describe 'GET /api/v1/background_checks/:id' do
    let(:report) { create(:report, :with_checks) }

    it 'returns report details' do
      get "/api/v1/background_checks/#{report.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq report.id
      expect(json['status']).to eq report.status
    end

    it 'includes check details' do
      get "/api/v1/background_checks/#{report.id}"

      json = JSON.parse(response.body)
      expect(json['checks']).to be_an(Array)
      expect(json['checks'].first).to have_key('type')
      expect(json['checks'].first).to have_key('status')
    end

    it 'returns not found for non-existent report' do
      get '/api/v1/background_checks/99999'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to eq 'Report not found'
    end
  end
end
