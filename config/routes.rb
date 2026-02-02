Rails.application.routes.draw do
  get "entries/index"
  get "entries/new"
  get "entries/details"
  get "users/new"
  get "users/show"
  get "sessions/new"
  root "home#index"

  get "/login",  to: "sessions#new"
  get "/signup", to: "users#new"
  get "/account", to: "users#show"

  get "/entries", to: "entries#index"
  get "/entries/new", to: "entries#new"            # map step
  get "/entries/new/details", to: "entries#details" # details form step

  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  post "/signup", to: "users#create"

  get  "/account",          to: "users#show"
  patch "/account/email",   to: "users#update_email"
  patch "/account/password",to: "users#update_password"

end

