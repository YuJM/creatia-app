# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  # GitHub OAuth
  if Rails.application.credentials.dig(:github, :client_id)
    provider :github,
             Rails.application.credentials.github[:client_id],
             Rails.application.credentials.github[:client_secret],
             scope: 'user,repo,admin:org,admin:repo_hook'
  end
  
  # Google OAuth (기존)
  if Rails.application.credentials.dig(:google, :client_id)
    provider :google_oauth2,
             Rails.application.credentials.google[:client_id],
             Rails.application.credentials.google[:client_secret],
             {
               scope: 'email,profile,calendar',
               prompt: 'select_account',
               image_aspect_ratio: 'square',
               image_size: 128,
               access_type: 'offline'
             }
  end
end

# CSRF protection
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true