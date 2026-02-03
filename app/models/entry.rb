class Entry < ApplicationRecord
  belongs_to :user
  has_one_attached :photo

  validates :photo, presence: true
  validates :latitude, :longitude, presence: true
end
