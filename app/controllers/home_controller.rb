class HomeController < ApplicationController
  def index
    @entries =
      if logged_in?
        current_user.entries.order(created_at: :desc)
      else
        []
      end
  end
end
