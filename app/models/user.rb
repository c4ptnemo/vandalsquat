class User < ApplicationRecord
  has_secure_password

  has_many :entries, dependent: :destroy

  has_many :trusted_devices, dependent: :destroy

  # Username validation (now required instead of email)
  validates :username, 
    presence: true, 
    uniqueness: { case_sensitive: false },
    format: { with: /\A[a-zA-Z0-9_]+\z/, message: "only allows letters, numbers, and underscores" },
    length: { minimum: 3, maximum: 20 }

  # Email is now optional
  validates :email, 
    uniqueness: { case_sensitive: false, allow_blank: true },
    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  # Normalize username to lowercase
  before_save :downcase_username

  # Two-Factor Authentication Methods
  
  def enable_two_factor!
    # Generate a new secret for TOTP
    self.otp_secret = ROTP::Base32.random
    # Generate backup codes
    self.otp_backup_codes = generate_backup_codes.to_json
    self.otp_enabled = true
    save!
  end

  def disable_two_factor!
    self.otp_secret = nil
    self.otp_backup_codes = nil
    self.otp_enabled = false
    save!
  end

  def verify_otp(code)
    return false unless otp_enabled?
    
    totp = ROTP::TOTP.new(otp_secret)
    
    # Check if the code is valid (with 30 second drift tolerance)
    if totp.verify(code, drift_behind: 30, drift_ahead: 30)
      return true
    end
    
    # Check backup codes
    verify_backup_code(code)
  end

  def verify_backup_code(code)
    return false if otp_backup_codes.blank?
    
    codes = JSON.parse(otp_backup_codes)
    
    if codes.include?(code)
      # Remove used backup code
      codes.delete(code)
      self.otp_backup_codes = codes.to_json
      save!
      return true
    end
    
    false
  end

  def otp_provisioning_uri(issuer = 'VandalSquat')
    return nil unless otp_secret
    
    totp = ROTP::TOTP.new(otp_secret)
    totp.provisioning_uri("#{issuer}:#{username}")
  end

  def backup_codes
    return [] if otp_backup_codes.blank?
    JSON.parse(otp_backup_codes)
  end

  def trust_device(request)
    trusted_devices.create(
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      last_used_at: Time.current
    )
  end

  def revoke_all_devices!
    trusted_devices.destroy_all
  end

  private

  def downcase_username
    self.username = username.downcase.strip if username.present?
  end

  def generate_backup_codes
    # Generate 10 random backup codes
    10.times.map { SecureRandom.hex(4).upcase }
  end

end
