class SessionsController < ApplicationController
  def new
    # renders login form
  end

  def create
    user = User.find_by(username: params[:username]&.downcase)

    if user&.authenticate(params[:password])
      # Check if 2FA is enabled
      if user.otp_enabled?
        # Check if device is trusted
        trusted_device = check_trusted_device(user)
        
        if trusted_device&.active?
          # Device is trusted - skip 2FA
          trusted_device.touch_last_used
          session[:user_id] = user.id
          redirect_to root_path, notice: "Logged in successfully (trusted device)."
        else
          # Need 2FA verification
          session[:pending_2fa_user_id] = user.id
          redirect_to two_factor_verify_path
        end
      else
        # No 2FA - log in directly
        session[:user_id] = user.id
        redirect_to root_path, notice: "Logged in successfully."
      end
    else
      @error = "Invalid username or password"
      render :new, status: :unprocessable_entity
    end
  end

  def two_factor_verify
    # Show 2FA code entry form
    unless session[:pending_2fa_user_id]
      redirect_to login_path, alert: "Please log in first."
    end
  end

  def two_factor_authenticate
    user = User.find_by(id: session[:pending_2fa_user_id])
    
    unless user
      redirect_to login_path, alert: "Session expired. Please log in again."
      return
    end

    code = params[:otp_code]
    remember_device = params[:remember_device] == '1'

    if user.verify_otp(code)
      # 2FA successful
      session.delete(:pending_2fa_user_id)
      session[:user_id] = user.id
      
      # Trust this device if requested
      if remember_device
        device = user.trust_device(request)
        cookies.permanent.encrypted[:device_token] = device.device_token
      end
      
      redirect_to root_path, notice: "Logged in successfully."
    else
      flash.now[:alert] = "Invalid authentication code"
      render :two_factor_verify, status: :unprocessable_entity
    end
  end

  def destroy
    # Remove device token cookie on logout
    cookies.delete(:device_token)
    reset_session
    redirect_to login_path, notice: "Logged out."
  end
  
  private
  
  def check_trusted_device(user)
    device_token = cookies.encrypted[:device_token]
    return nil unless device_token.present?
    
    user.trusted_devices.find_by(device_token: device_token)
  end
end
