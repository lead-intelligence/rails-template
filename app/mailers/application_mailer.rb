class ApplicationMailer < ActionMailer::Base
  default from: -> { email_address_with_name("from@example.com", I18n.t("app_name")) }
  layout "mailer"

  rescue_from ActiveJob::DeserializationError, with: -> { }
end
