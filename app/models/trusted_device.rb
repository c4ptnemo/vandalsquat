# app/models/trusted_device.rb

class TrustedDevice < ApplicationRecord
  belongs_to :user
  
  before_create :set_device_token
  before_create :set_expiration
  before_create :enforce_device_limit
  
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  
  DEVICE_LIMIT = 2
  EXPIRATION_DAYS = 7
  
  def expired?
    expires_at < Time.current
  end
  
  def touch_last_used
    update(last_used_at: Time.current)
  end
  
  def device_description
    return device_name if device_name.present?
    
    # Parse user agent to create friendly name
    agent = user_agent.to_s.downcase
    
    browser = case agent
    when /firefox/ then "Firefox"
    when /chrome/ then "Chrome"
    when /safari/ then "Safari"
    when /edge/ then "Edge"
    else "Unknown Browser"
    end
    
    os = case agent
    when /windows/ then "Windows"
    when /mac/ then "Mac"
    when /iphone/ then "iPhone"
    when /ipad/ then "iPad"
    when /android/ then "Android"
    when /linux/ then "Linux"
    else "Unknown OS"
    end
    
    "#{browser} on #{os}"
  end
  
  private
  
  def set_device_token
    self.device_token = SecureRandom.hex(32)
  end
  
  def set_expiration
    self.expires_at = EXPIRATION_DAYS.days.from_now
  end
  
  def enforce_device_limit
    # Remove oldest device if limit exceeded
    active_devices = user.trusted_devices.active.order(last_used_at: :desc)
    
    if active_devices.count >= DEVICE_LIMIT
      # Remove the oldest (least recently used)
      active_devices.last.destroy
    end
  end
end
