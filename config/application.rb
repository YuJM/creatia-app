require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CreatiaApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Asia/Seoul"
    config.i18n.default_locale = :ko
    config.i18n.available_locales = [:ko, :en]
    # config.eager_load_paths << Rails.root.join("extras")
    
    # Use UUID as primary key for all models
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end
    
    # Load middleware path
    config.autoload_paths << Rails.root.join('app/middleware')
    
    # Multi-tenant security middleware (프로덕션과 필요시에만)
    if Rails.env.production? || ENV['ENABLE_RATE_LIMITING'] == 'true'
      config.middleware.use 'TenantRateLimiter'
    end
    
    # Security headers
    config.force_ssl = Rails.env.production?
    config.ssl_options = {
      redirect: {
        exclude: ->(request) { 
          request.path.start_with?('/up') || 
          request.path.start_with?('/health') 
        }
      }
    }
    
    # Session security
    config.session_store :cookie_store, 
                        key: '_creatia_session',
                        secure: Rails.env.production?,
                        httponly: true,
                        same_site: :lax,
                        expire_after: 8.hours
  end
end
