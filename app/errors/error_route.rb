class ErrorRoute
  SOURCES = [ "application.action_dispatch", ActiveSupport::ErrorReporter::DEFAULT_SOURCE ].freeze

  def self.call(_error, context:, source:, **)
    return context unless SOURCES.include?(source)

    request = context[:controller]&.request
    pattern = request&.route_uri_pattern
    return context unless pattern

    context.merge(route: "#{request.request_method} #{pattern}")
  end
end
