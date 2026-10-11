class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  skip_before_action :track_ahoy_visit
  before_action :resume_session
  before_action :track_ahoy_visit
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  around_action :switch_locale

  private

  def switch_locale(&action)
    I18n.with_locale(locale_from_accept_language || I18n.default_locale, &action)
  end

  def locale_from_accept_language
    Rack::Request.new(request.env).accept_language
      .select { |_range, quality| quality.positive? }
      .sort_by.with_index { |(_range, quality), position| [ -quality, position ] }
      .map { |range, _quality| range.split("-", 2).first.downcase.to_sym }
      .find { |locale| I18n.available_locales.include?(locale) }
  end

  def pundit_user
    Current.user
  end

  def user_not_authorized
    redirect_back_or_to root_path, alert: t("authorization.not_authorized")
  end

  def ensure_within_quota
    head :forbidden if Current.user.messages_remaining_today.zero?
  end
end
