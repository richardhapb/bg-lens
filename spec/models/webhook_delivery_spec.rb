require 'rails_helper'

RSpec.describe WebhookDelivery, type: :model do
  describe 'associations' do
    it { should belong_to(:report) }
  end

  describe 'validations' do
    it { should validate_presence_of(:url) }
    it { should validate_inclusion_of(:status).in_array(%w[pending delivered failed]) }
  end

  describe 'scopes' do
    let!(:pending_delivery) { create(:webhook_delivery, status: 'pending') }
    let!(:delivered_delivery) { create(:webhook_delivery, :delivered) }

    it 'returns pending deliveries' do
      expect(WebhookDelivery.pending).to include(pending_delivery)
      expect(WebhookDelivery.pending).not_to include(delivered_delivery)
    end
  end
end
