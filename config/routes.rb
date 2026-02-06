Rails.application.routes.draw do
  root "home#index"

  # Auth
  get    "/login",  to: "sessions#new"
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # Users / Account
  get   "/signup", to: "users#new"
  post  "/signup", to: "users#create"
  get   "/account", to: "users#show"
  patch "/account/email", to: "users#update_email"
  patch "/account/password", to: "users#update_password"

  # Entries
  resources :entries, only: [:index, :new, :create, :edit, :update, :destroy]
  get "/entries/new/details", to: "entries#details"

  # Two-Factor Authentication routes
get '/account/two-factor', to: 'users#two_factor', as: 'two_factor'
post '/account/two-factor/enable', to: 'users#enable_two_factor', as: 'enable_two_factor'
post '/account/two-factor/verify', to: 'users#verify_two_factor_setup', as: 'verify_two_factor_setup'
delete '/account/two-factor/disable', to: 'users#disable_two_factor', as: 'disable_two_factor'

# 2FA login verification
get '/login/verify', to: 'sessions#two_factor_verify', as: 'two_factor_verify'
post '/login/verify', to: 'sessions#two_factor_authenticate', as: 'two_factor_authenticate'

end
