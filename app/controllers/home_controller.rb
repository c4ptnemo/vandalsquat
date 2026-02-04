class HomeController < ApplicationController
  before_action :require_login

  def index
    @entries = current_user.entries.order(created_at: :desc)
  end
end
