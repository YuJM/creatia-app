# Hotwire Livereload Configuration
Rails.application.configure do
  # Force full page reload for changes in these paths
  config.hotwire_livereload.force_reload_paths << Rails.root.join("app/views")
  config.hotwire_livereload.force_reload_paths << Rails.root.join("app/assets/stylesheets")
  config.hotwire_livereload.force_reload_paths << Rails.root.join("app/javascript")
  config.hotwire_livereload.force_reload_paths << Rails.root.join("config/routes.rb")
  config.hotwire_livereload.debounce_delay_ms = 300 # in milliseconds
end