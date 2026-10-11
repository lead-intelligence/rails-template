# frozen_string_literal: true

ReActionView.configure do |config|
  config.intercept_erb = true
  config.debug_mode = Rails.env.development?
  config.validation_mode = :none if Rails.env.production?
end
