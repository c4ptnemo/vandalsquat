class UsersController < ApplicationController
  before_action :require_login, only: [:show, :update_email, :update_password]

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

  def update_email
    @user = current_user

    unless @user.authenticate(params[:current_password])
      flash.now[:alert] = "Current password is incorrect"
      return render :show, status: :unprocessable_entity
    end

    if @user.update(email_params)
      redirect_to account_path, notice: "Email updated."
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
      redirect_to login_path, notice: "Password updated. Please log in again."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def email_params
    params.require(:user).permit(:email)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
