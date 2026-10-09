module SuperadminAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_superadmin!
  end

  private

  def authenticate_superadmin!
    username = Rails.application.credentials.dig(:superadmin, :username) || ENV["SUPERADMIN_USER"]
    password = Rails.application.credentials.dig(:superadmin, :password) || ENV["SUPERADMIN_PASSWORD"]

    return request_http_basic_authentication("Superadmin") if username.blank? || password.blank?

    authenticate_or_request_with_http_basic("Superadmin") do |given_username, given_password|
      ActiveSupport::SecurityUtils.secure_compare(given_username.to_s, username) &
        ActiveSupport::SecurityUtils.secure_compare(given_password.to_s, password)
    end
  end
end
