require "test_helper"

class JavascriptErrorsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

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
    sign_in_as(user)

    post javascript_errors_url, params: { message: "boom while signed in" }

    assert_response :no_content
    assert_equal user.id, SolidErrors::Error.last.occurrences.last.context["user_id"]
  end

  test "it needs no session" do
    post javascript_errors_url, params: { message: "boom" }

    assert_response :no_content
  end

  test "rate limits repeated error reports" do
    30.times { post javascript_errors_url, params: { message: "boom" } }

    post javascript_errors_url, params: { message: "boom" }

    assert_response :too_many_requests
  end
end
