source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# Framework translations (dates, numbers, Active Record error messages) for every locale.
gem "rails-i18n", "~> 8.0"
# Native iOS and Android apps driven from the views [https://github.com/bruno-costanzo/charco_mobile]
gem "charco_mobile", git: "git@github.com:bruno-costanzo/charco_mobile.git", branch: "main", glob: "gem/*.gemspec"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
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

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

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
gem "image_processing", "~> 2.0"
gem "ruby-vips", "~> 2.3"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Finds missing/unused translations and keeps locale files in sync [https://github.com/glebm/i18n-tasks]
  gem "i18n-tasks", "~> 1.0", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "cuprite"

  # Accessibility auditing (axe-core) inside system tests [https://github.com/dequelabs/axe-core-gems]
  gem "axe-core-api"
end

gem "meta-tags", "~> 2.23"

gem "active_storage_validations", "~> 4.1"

gem "ruby_llm", "~> 1.16"

gem "dotenv-rails", "~> 3.2", groups: [ :development, :test ]

gem "webmock", "~> 3.26", group: :test

gem "schematist", "~> 1.1"

gem "lexxy", "~> 0.9.30"

gem "neighbor", "~> 1.2"

gem "sqlite-vec", "~> 0.1.9"

gem "console1984", "~> 0.2.4"

gem "simplecov", "~> 1.1", group: :test, require: false
gem "simplecov-console", "~> 0.9", group: :test, require: false

gem "money-rails", "~> 3.0"

gem "solid_errors", "~> 0.7.0"

gem "lucide-rails", "~> 0.7.4"

gem "letter_opener_web", "~> 3.0", group: :development

gem "noticed", "~> 3.0"

gem "bullet", "~> 8.1", groups: [ :development, :test ]

gem "onlylogs", "~> 0.7"

gem "pundit", "~> 2.5"

gem "madmin", "~> 2.0"

gem "mission_control-jobs", "~> 1.2"

gem "railspress-engine", "~> 1.4"

gem "rubyzip", "~> 3.0"

# Markdown rendering for the /docs site (already in the bundle through railspress-engine)
gem "redcarpet", "~> 3.6"

# First-party analytics: visits and events stored in this app's own database [https://github.com/ankane/ahoy]
gem "ahoy_matey", "~> 5.4"

gem "action_push_native", "~> 0.3"

gem "reactionview", "~> 0.6.0"
