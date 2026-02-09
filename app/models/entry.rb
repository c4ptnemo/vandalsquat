class Entry < ApplicationRecord
  belongs_to :user
  has_one_attached :photo

  validates :photo, presence: true
  validates :latitude, :longitude, presence: true
  
  # File type validation using attached: true
  validate :acceptable_photo

  private

  def acceptable_photo
    return unless photo.attached?

    unless photo.blob.content_type.in?(['image/png', 'image/jpg', 'image/jpeg', 'image/gif', 'image/webp'])
      errors.add(:photo, 'must be a PNG, JPG, GIF, or WebP image')
    end

    if photo.blob.byte_size > 10.megabytes
      errors.add(:photo, 'must be less than 10MB')
    end
  end
end