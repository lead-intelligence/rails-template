class JavascriptErrorsController < ApplicationController
  MAX_MESSAGE_LENGTH = 1000
  MAX_BACKTRACE_LINES = 20
  MAX_BODY_SIZE = 64.kilobytes

  TOO_LARGE = ->(_env) { [ 413, {}, [] ] }

  def self.within_body_limit?(request)
    request.content_length.to_i <= MAX_BODY_SIZE
  end

  allow_unauthenticated_access
  rate_limit to: 30, within: 1.minute, with: -> { head :too_many_requests }

  def create
    message = params[:message].to_s.strip
    return head :bad_request if message.blank?

    Rails.error.report(javascript_error(message), handled: true, source: "javascript", context: error_context)
    head :no_content
  end

  private

  def javascript_error(message)
    JavascriptError.new(message.truncate(MAX_MESSAGE_LENGTH)).tap do |error|
      error.set_backtrace(backtrace_from_stack)
    end
  end

  def backtrace_from_stack
    params[:stack].to_s.each_line.lazy.filter_map { |line| line.strip.presence }.first(MAX_BACKTRACE_LINES)
  end

  def error_context
    {
      url: params[:url].to_s.truncate(MAX_MESSAGE_LENGTH),
      user_agent: request.user_agent,
      user_id: Current.user&.id
    }
  end
end
