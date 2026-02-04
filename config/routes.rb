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
end
