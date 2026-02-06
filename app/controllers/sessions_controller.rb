class SessionsController < ApplicationController
  def new
    # renders login form
  end

  def create
    user = User.find_by(username: params[:username]&.downcase)

    if user&.authenticate(params[:password])
      # Check if 2FA is enabled
      if user.otp_enabled?
        # Store user ID in session temporarily
        session[:pending_2fa_user_id] = user.id
        redirect_to two_factor_verify_path
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

    if user.verify_otp(code)
      # 2FA successful
      session.delete(:pending_2fa_user_id)
      session[:user_id] = user.id
      redirect_to root_path, notice: "Logged in successfully."
    else
      flash.now[:alert] = "Invalid authentication code"
      render :two_factor_verify, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Logged out."
  end
end
