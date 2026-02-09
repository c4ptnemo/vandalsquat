class UsersController < ApplicationController
  before_action :require_login, only: [:show, :update_email, :update_password, :two_factor, :enable_two_factor, :disable_two_factor, :verify_two_factor_setup, :destroy]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to login_path, notice: "Account created. Please log in."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @user = current_user
  end

  def destroy
    @user = current_user
    
    # Require password confirmation for security
    unless @user.authenticate(params[:password])
      redirect_to account_path, alert: "Incorrect password. Account not deleted."
      return
    end
    
    # Delete all user's entries and associated photos from Cloudinary
    @user.entries.destroy_all
    
    # Delete the user account
    @user.destroy
    
    # Log them out
    reset_session
    
    redirect_to root_path, notice: "Your account has been permanently deleted."
  end

  # Two-Factor Authentication Management
  
  def two_factor
    @user = current_user
  end

  def enable_two_factor
    @user = current_user
    
    # Generate OTP secret and backup codes
    @user.enable_two_factor!
    
    # Generate QR code
    require 'rqrcode'
    qrcode = RQRCode::QRCode.new(@user.otp_provisioning_uri)
    @qr_code_svg = qrcode.as_svg(
      module_size: 4,
      fill: 'ffffff',
      color: '000000'
    )
    
    @backup_codes = @user.backup_codes
    
    render :two_factor_verify_setup
  end

  def verify_two_factor_setup
    @user = current_user
    code = params[:otp_code]
    
    if @user.verify_otp(code)
      redirect_to two_factor_path, notice: "Two-factor authentication enabled successfully!"
    else
      flash.now[:alert] = "Invalid code. Please try again."
      
      # Regenerate QR code for display
      require 'rqrcode'
      qrcode = RQRCode::QRCode.new(@user.otp_provisioning_uri)
      @qr_code_svg = qrcode.as_svg(
        module_size: 4,
        fill: 'ffffff',
        color: '000000'
      )
      @backup_codes = @user.backup_codes
      
      render :two_factor_verify_setup, status: :unprocessable_entity
    end
  end

  def disable_two_factor
    @user = current_user
    
    unless @user.authenticate(params[:password])
      flash[:alert] = "Incorrect password"
      redirect_to two_factor_path
      return
    end
    
    @user.disable_two_factor!
    redirect_to two_factor_path, notice: "Two-factor authentication disabled."
  end

  # Email/Password Updates (optional email now)
  
  def update_email
    @user = current_user

    unless @user.authenticate(params[:current_password])
      flash.now[:alert] = "Current password is incorrect"
      return render :show, status: :unprocessable_entity
    end

    if @user.update(email_params)
      redirect_to account_path, flash: { success: "Email updated." }
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    @user = current_user

    unless @user.authenticate(params[:current_password])
      flash.now[:alert] = "Current password is incorrect"
      return render :show, status: :unprocessable_entity
    end

    if @user.update(password_params)
      reset_session
      redirect_to login_path, flash: { success: "Password updated. Please log in again." }
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :email, :password, :password_confirmation)
  end

  def email_params
    params.require(:user).permit(:email)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end