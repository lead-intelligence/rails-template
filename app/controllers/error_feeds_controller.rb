class ErrorFeedsController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  RATE_LIMIT = 60

  rate_limit to: RATE_LIMIT, within: 1.minute, with: -> { head :too_many_requests }
  before_action :authenticate_watcher!

  def show
    since = Integer(params.fetch(:since, 0).to_s, 10, exception: false)
    return head :bad_request if since.nil? || since.negative?

    render json: ErrorFeed.new(since: since).page
  end

  private

  def authenticate_watcher!
    token = [ Rails.application.credentials.error_feed_token, ENV["ERROR_FEED_TOKEN"] ].find(&:present?)
    return head :not_found if token.nil?

    authenticate_or_request_with_http_token do |given, _options|
      ActiveSupport::SecurityUtils.secure_compare(given, token)
    end
  end
end
