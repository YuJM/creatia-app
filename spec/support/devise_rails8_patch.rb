# Rails 8 Lazy Loading Routes fix for Devise
# This patch ensures Devise mappings are loaded before tests run
# Reference: https://github.com/heartcombo/devise/issues/5705

require 'devise'

module Devise
  class << self
    alias_method :original_mappings, :mappings
    
    def mappings
      # Force load routes if they haven't been loaded yet
      Rails.application.try(:reload_routes_unless_loaded)
      original_mappings
    end
  end
end