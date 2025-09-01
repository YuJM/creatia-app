# frozen_string_literal: true

# Execution Data Models Configuration
# This file defines which implementation to use for execution data models.
# This allows for easy switching between database backends in the future.

Rails.application.configure do
  # Current implementation: MongoDB
  # Future options could include: PostgreSQL, TimescaleDB, etc.
  
  config.execution_data_backend = :mongodb
  
  # Model mappings based on current backend
  case config.execution_data_backend
  when :mongodb
    config.execution_models = {
      task: 'Mongodb::MongoTask',
      sprint: 'Mongodb::MongoSprint',
      pomodoro_session: 'Mongodb::MongoPomodoroSession',
      activity: 'Mongodb::MongoActivity',
      comment: 'Mongodb::MongoComment',
      metrics: 'Mongodb::MongoMetrics'
    }.freeze
  when :postgresql
    # Future PostgreSQL implementation
    config.execution_models = {
      task: 'Postgresql::Task',
      sprint: 'Postgresql::Sprint',
      pomodoro_session: 'Postgresql::PomodoroSession'
      # ... etc
    }.freeze
  else
    raise "Unknown execution data backend: #{config.execution_data_backend}"
  end
end