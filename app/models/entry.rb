class Entry < ApplicationRecord
  belongs_to :user
  has_one_attached :photo

  # File security validations
  validates :photo, presence: true,
                    content_type: ['image/png', 'image/jpg', 'image/jpeg', 'image/gif', 'image/webp'],
                    size: { less_than: 10.megabytes, message: 'must be less than 10MB' }
  
  validates :latitude, :longitude, presence: true
  validates :writer_name, presence: true, allow_blank: true
  validates :pin_type, inclusion: { in: %w[Spot Tag Throw Piece] }, allow_nil: true
end