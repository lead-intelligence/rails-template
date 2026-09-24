SolidErrors.base_controller_class = "SolidErrorsBaseController"
SolidErrors.email_to = Rails.application.credentials.dig(:solid_errors, :email_to) || ENV["SOLID_ERRORS_EMAIL_TO"]
SolidErrors.email_from = Rails.application.credentials.dig(:solid_errors, :email_from) || ENV["SOLID_ERRORS_EMAIL_FROM"] || SolidErrors.email_from
SolidErrors.send_emails = SolidErrors.email_to.present?

Rails.error.add_middleware(->(error, **options) { ErrorRoute.call(error, **options) })
