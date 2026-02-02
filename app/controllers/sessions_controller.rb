class SessionsController < ApplicationController
  def new
    # renders login form
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path
    else
      @error = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path
  end

  def destroy
  reset_session
  redirect_to login_path
  end

end
