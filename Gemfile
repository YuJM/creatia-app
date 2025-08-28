source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Fast JSON serialization [https://github.com/okuramasafumi/alba]
gem "alba", "~> 3.5"

# Authentication
gem "devise", "~> 4.9"

# Authorization
gem "pundit", "~> 2.4"

# Service object utilities
gem "attr_extras", "~> 7.1"
gem "memo_wise", "~> 1.8"
gem "dry-monads", "~> 1.6"
gem "dry-validation", "~> 1.10"

# Multi-tenancy
gem "acts_as_tenant", "~> 1.0"

# OAuth authentication
gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2", "~> 1.2"
gem "omniauth-github", "~> 2.0"
gem "omniauth-rails_csrf_protection", "~> 1.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Load environment variables from .env file [https://github.com/bkeepers/dotenv]
  gem "dotenv-rails"
  
  # RSpec for testing [https://github.com/rspec/rspec-rails]
  gem "rspec-rails", "~> 8.0.0"
  
  # Factory Bot for test data [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails"
  
  # Faker for generating fake data [https://github.com/faker-ruby/faker]
  gem "faker"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  
  # Live reload for Hotwire [https://github.com/kirillplatonov/hotwire-livereload]
  gem "hotwire-livereload"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  
  # Additional RSpec matchers and tools
  gem "shoulda-matchers", "~> 6.4"
  gem "database_cleaner-active_record"
  gem "simplecov", require: false
  gem "rails-controller-testing"
  gem "pundit-matchers", "~> 3.1"
end

gem "tailwindcss-ruby", "~> 4.1"
