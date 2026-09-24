require "test_helper"

class ErrorRouteTest < ActionDispatch::IntegrationTest
  test "an unhandled request error records its route pattern, never the raw path" do
    context = route_for(controller_for("/passwords/:token/edit(.:format)"), source: "application.action_dispatch")

    assert_equal "GET /passwords/:token/edit(.:format)", context[:route]
  end

  test "an error the app reports itself during a request records the route too" do
    context = route_for(controller_for("/documents/:id(.:format)"), source: ActiveSupport::ErrorReporter::DEFAULT_SOURCE)

    assert_equal "GET /documents/:id(.:format)", context[:route]
  end

  test "a report with its own source describes somewhere else and gets no route" do
    context = route_for(controller_for("/javascript_errors(.:format)"), source: "javascript")

    assert_nil context[:route]
  end

  test "an error outside a request leaves the context as it was" do
    context = ErrorRoute.call(StandardError.new, context: { job: "SomeJob" }, source: ActiveSupport::ErrorReporter::DEFAULT_SOURCE)

    assert_equal({ job: "SomeJob" }, context)
  end

  test "a request no route matched leaves the context as it was" do
    controller = controller_for(nil)

    assert_equal({ controller: controller }, route_for(controller, source: "application.action_dispatch"))
  end

  test "Solid Errors stores the route of a reported request error" do
    Rails.error.report(StandardError.new("route probe"), context: { controller: controller_for("/documents/:id(.:format)") })

    assert_equal "GET /documents/:id(.:format)", SolidErrors::Occurrence.last.context["route"]
  end

  test "a browser error is not stored under the route that received the report" do
    post javascript_errors_url, params: { message: "Cannot read properties of null" }

    assert_response :no_content
    assert_nil SolidErrors::Occurrence.last.context["route"]
  end

  private

  def route_for(controller, source:)
    ErrorRoute.call(StandardError.new, context: { controller: controller }, source: source)
  end

  def controller_for(pattern)
    env = Rack::MockRequest.env_for("/passwords/secret-reset-token/edit", method: "GET")
    env["action_dispatch.route_uri_pattern"] = pattern if pattern
    ActionController::Base.new.tap { |controller| controller.set_request!(ActionDispatch::Request.new(env)) }
  end
end
