# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 8.0 application named CreatiaApp using PostgreSQL as the database, Tailwind CSS for styling, and Hotwire (Turbo & Stimulus) for interactivity.

## Essential Commands

### Development Setup
```bash
# Initial setup (installs dependencies, prepares database, starts server)
bin/setup

# Start development server with Tailwind CSS compilation
bin/dev
```

### Database Management
```bash
# Create and migrate database
bin/rails db:create
bin/rails db:migrate

# Reset database (drop, create, migrate, seed)
bin/rails db:reset

# Prepare database (create if needed, migrate, seed)
bin/rails db:prepare
```

### Testing
```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/user_test.rb

# Run system tests (uses Capybara with Selenium)
bin/rails test:system
```

### Code Quality
```bash
# Run security analysis
bin/brakeman

# Run Ruby linter (Omakase style)
bin/rubocop

# Run linter with auto-fix
bin/rubocop -A
```

### Asset Management
```bash
# Watch and compile Tailwind CSS
bin/rails tailwindcss:watch

# Build Tailwind CSS for production
bin/rails tailwindcss:build
```

### Console & Generators
```bash
# Rails console
bin/rails console

# Generate controller
bin/rails generate controller ControllerName action1 action2

# Generate model
bin/rails generate model ModelName field:type

# Generate scaffold (full CRUD)
bin/rails generate scaffold Resource field:type
```

## Architecture & Structure

### Database Architecture
- **Multi-database setup**: Separate databases for cache, queue, and cable in production
- **Solid adapters**: Using `solid_cache`, `solid_queue`, and `solid_cable` for database-backed Rails features
- **PostgreSQL**: Primary database with connection pooling configured

### Frontend Stack
- **Hotwire**: Turbo for SPA-like navigation, Stimulus for JavaScript behavior
- **Tailwind CSS**: Utility-first CSS framework with JIT compilation
- **Importmap**: ESM-based JavaScript management without build step
- **Propshaft**: Modern asset pipeline replacing Sprockets

### Deployment & Infrastructure
- **Kamal**: Docker-based deployment tool configured for containerized deployments
- **Thruster**: HTTP/2 asset server with X-Sendfile acceleration
- **Puma**: Multi-threaded web server with configurable workers

### Key Configuration Files
- `config/database.yml`: PostgreSQL configuration with multi-database setup
- `config/importmap.rb`: JavaScript module mappings
- `config/deploy.yml`: Kamal deployment configuration
- `Procfile.dev`: Development process management (web server + Tailwind watcher)

### Testing Framework
- **Minitest**: Default Rails testing framework
- **Capybara**: System testing with browser automation
- **Selenium WebDriver**: Browser driver for system tests

## Development Workflow

1. Use `bin/dev` to start both Rails server and Tailwind CSS watcher
2. Controllers go in `app/controllers/`, inherit from `ApplicationController`
3. Models go in `app/models/`, inherit from `ApplicationRecord`
4. Views use `.html.erb` templates in `app/views/`
5. Stimulus controllers go in `app/javascript/controllers/`
6. Tailwind styles are defined in `app/assets/tailwind/application.css`
7. Database migrations are in `db/migrate/` and separate migration paths exist for cache, queue, and cable databases

## Important Conventions

- Follow Rails conventions for naming (snake_case for files, CamelCase for classes)
- Use Rails generators when creating new resources to maintain consistency
- Keep business logic in models, not controllers (fat models, skinny controllers)
- Use concerns for shared behavior across models or controllers
- Leverage Turbo Frames and Streams for dynamic updates without full page reloads
- Use Stimulus for JavaScript behavior that needs to interact with Turbo