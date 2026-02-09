# config/initializers/session_store.rb

Rails.application.config.session_store :cookie_store,
  key: '_vandalsquat_session',
  secure: Rails.env.production?,  # HTTPS only in production
  httponly: true,                 # Prevent JavaScript access
  same_site: :lax                 # CSRF protection