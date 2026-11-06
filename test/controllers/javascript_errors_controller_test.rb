require "test_helper"

class JavascriptErrorsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup { sign_in_as users(:one) }

  test "a reported browser error reaches the error tracker" do
    assert_difference "SolidErrors::Error.count", 1 do
      post javascript_errors_url, params: { message: "Cannot read properties of null", stack: "at h (app.js:3:1)\nat g (app.js:9:2)", url: "http://example.com/documents" }
    end

    assert_response :no_content
    error = SolidErrors::Error.last
    assert_equal "JavascriptError", error.exception_class
    assert_equal "Cannot read properties of null", error.message
  end

  test "a blank message is rejected without recording anything" do
    assert_no_difference "SolidErrors::Error.count" do
      post javascript_errors_url, params: { message: "   " }
    end

    assert_response :bad_request
  end

  test "an oversized message and stack are truncated before being stored" do
    post javascript_errors_url, params: { message: "e" * 2000, stack: Array.new(50) { |i| "at frame#{i}" }.join("\n") }

    assert_response :no_content
    assert_operator SolidErrors::Error.last.message.length, :<=, JavascriptErrorsController::MAX_MESSAGE_LENGTH
  end

  test "a body over the size limit is refused before anything is reported" do
    reports = []
    callback = Object.new.tap { |subscriber| subscriber.define_singleton_method(:report) { |error, **| reports << error } }
    Rails.error.subscribe(callback)

    post javascript_errors_url, params: { message: "boom", stack: "x" * JavascriptErrorsController::MAX_BODY_SIZE }

    assert_response :content_too_large
    assert_empty reports
  ensure
    Rails.error.unsubscribe(callback)
  end

  test "a report from a signed in person carries their id in the error context" do
    user = users(:one)

    post javascript_errors_url, params: { message: "boom while signed in" }

    assert_response :no_content
    assert_equal user.id, SolidErrors::Error.last.occurrences.last.context["user_id"]
  end

  test "an anonymous report goes to the log, not to the error tracker" do
    delete session_url
    logged = capture_log { post javascript_errors_url, params: { message: "boom from a visitor" } }

    assert_response :no_content
    assert_equal 0, SolidErrors::Error.count
    assert_includes logged, "boom from a visitor"
  end

  test "rate limits repeated error reports" do
    30.times { post javascript_errors_url, params: { message: "boom" } }

    post javascript_errors_url, params: { message: "boom" }

    assert_response :too_many_requests
  end

  private

  def capture_log
    output = StringIO.new
    Rails.logger.broadcast_to(logger = ActiveSupport::Logger.new(output))
    yield
    output.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end
end
