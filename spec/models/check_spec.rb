require 'rails_helper'

RSpec.describe Check, type: :model do
  describe 'associations' do
    it { should belong_to(:report) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:check_type).in_array(%w[criminal employment education]) }
    it { should validate_inclusion_of(:status).in_array(%w[pending processing completed failed]) }
  end

  describe '#process!' do
    let(:report) { create(:report) }
    let(:check) { create(:check, :criminal, report: report) }

    it 'updates status to processing then completed' do
      expect(check.status).to eq('pending')
      check.process!
      expect(check.status).to eq('completed')
    end

    it 'stores result from strategy' do
      check.process!
      expect(check.result).to be_a(Hash)
      expect(check.result).to have_key('checked_at')
    end

    context 'when strategy raises an error' do
      before do
        allow_any_instance_of(CriminalCheckStrategy).to receive(:execute).and_raise(StandardError, 'API error')
      end

      it 'marks check as failed and re-raises' do
        expect { check.process! }.to raise_error(StandardError, 'API error')
        expect(check.status).to eq('failed')
        expect(check.result['error']).to eq('API error')
      end
    end
  end

  describe 'strategy selection' do
    let(:report) { create(:report) }

    it 'uses CriminalCheckStrategy for criminal checks' do
      check = create(:check, :criminal, report: report)
      expect(CriminalCheckStrategy).to receive(:new).and_call_original
      check.process!
    end

    it 'uses EmploymentCheckStrategy for employment checks' do
      check = create(:check, :employment, report: report)
      expect(EmploymentCheckStrategy).to receive(:new).and_call_original
      check.process!
    end

    it 'uses EducationCheckStrategy for education checks' do
      check = create(:check, :education, report: report)
      expect(EducationCheckStrategy).to receive(:new).and_call_original
      check.process!
    end
  end
end
