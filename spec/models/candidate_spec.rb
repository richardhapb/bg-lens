require 'rails_helper'

RSpec.describe Candidate, type: :model do
  describe 'associations' do
    it { should have_many(:reports).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:candidate, ssn: 'ABC-45-6789') }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:ssn) }
    it { should validate_uniqueness_of(:ssn) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:dob) }
  end
end
