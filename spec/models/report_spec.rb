require 'rails_helper'

RSpec.describe Report, type: :model do
  describe 'associations' do
    it { should belong_to(:candidate) }
    it { should have_many(:checks).dependent(:destroy) }
    it { should have_many(:webhook_deliveries).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:report) }
    it { should validate_presence_of(:idempotency_key) }
    it { should validate_uniqueness_of(:idempotency_key) }
    it { should validate_presence_of(:status) }
  end

  describe 'state machine' do
    let(:candidate) { create(:candidate) }
    let(:report) { create(:report, candidate: candidate) }

    it 'starts in pending state' do
      expect(report.pending?).to be true
    end

    it 'transitions from pending to processing' do
      report.start_processing!
      expect(report.processing?).to be true
    end

    context 'when completing' do
      before do
        create(:check, :completed, report: report)
        create(:check, :completed, report: report)
        report.start_processing!
      end

      it 'transitions to completed when all checks are done' do
        expect { report.complete! }.not_to raise_error
        expect(report.completed?).to be true
        expect(report.completed_at).to be_present
      end

      it 'enqueues webhook delivery job' do
        webhook = create(:webhook_delivery, report: report, status: "pending")
        expect {
          report.complete!
        }.to have_enqueued_job(WebhookDeliveryJob).with(webhook.id)
      end
    end

    context 'when checks are not complete' do
      before do
        create(:check, report: report, status: 'pending')
        report.start_processing!
      end

      it 'does not transition to completed' do
        expect { report.complete! }.to raise_error(AASM::InvalidTransition)
      end
    end

    it 'transitions to failed from pending' do
      report.mark_failed!
      expect(report.failed?).to be true
    end

    it 'transitions to failed from processing' do
      report.start_processing!
      report.mark_failed!
      expect(report.failed?).to be true
    end
  end

  describe '#all_checks_completed?' do
    let(:report) { create(:report) }

    it 'returns true when all checks are completed' do
      create(:check, :completed, report: report)
      create(:check, :completed, report: report)
      expect(report.all_checks_completed?).to be true
    end

    it 'returns false when some checks are not completed' do
      create(:check, :completed, report: report)
      create(:check, report: report, status: 'pending')
      expect(report.all_checks_completed?).to be false
    end
  end
end
