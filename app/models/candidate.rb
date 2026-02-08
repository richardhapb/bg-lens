class Candidate < ApplicationRecord
  has_many :reports, dependent: :destroy

  validates :name, presence: true
  validates :ssn, presence: true, uniqueness: true
  validates :email, presence: true
  validates :dob, presence: true
end
