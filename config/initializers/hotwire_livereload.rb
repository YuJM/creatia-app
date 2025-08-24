# Hotwire Livereload Configuration
if defined?(HotwireLivereload)
  HotwireLivereload.configure do |config|
    # Watch for changes in these directories
    config.watch_paths = [
      Rails.root.join("app/views"),
      Rails.root.join("app/helpers"),
      Rails.root.join("app/assets/stylesheets"),
      Rails.root.join("app/javascript"),
      Rails.root.join("config/locales")
    ]

    # Watch for changes in these file extensions
    config.watch_extensions = %w[erb rb yml yaml css scss js json]

    # Reload strategy (:page or :turbo)
    config.reload_strategy = :turbo

    # Debounce time in milliseconds
    config.debounce_delay = 100

    # Enable/disable livereload
    config.enabled = Rails.env.development?
  end
end