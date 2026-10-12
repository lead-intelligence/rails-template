class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  rescue_from ActiveJob::DeserializationError, with: -> { }
end
