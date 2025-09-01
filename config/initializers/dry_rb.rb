# frozen_string_literal: true

# dry-rb ecosystem initialization
require 'dry-monads'
require 'dry-validation'
require 'dry-struct'
require 'dry-types'
require 'dry-container'
require 'dry-auto_inject'
require 'dry-transaction'
require 'dry-initializer'
require 'dry-schema'

# Load Types first
require Rails.root.join('app/structs/types')

# Ensure all dry-rb directories are eager loaded in development
if Rails.env.development?
  Rails.application.config.eager_load_paths += [
    Rails.root.join('app/lib'),
    Rails.root.join('app/repositories'),
    Rails.root.join('app/contracts'),
    Rails.root.join('app/transactions'),
    Rails.root.join('app/value_objects'),
    Rails.root.join('app/schemas')
  ]
end

# Initialize Container after all dependencies are loaded
Rails.application.config.after_initialize do
  # Container will be loaded when needed
end