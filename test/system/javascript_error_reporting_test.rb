require "application_system_test_case"

class JavascriptErrorReportingTest < ApplicationSystemTestCase
  test "an uncaught browser error reaches the error tracker" do
    sign_in_via_browser users(:one)

    page.execute_script(<<~JS)
      window.dispatchEvent(new ErrorEvent("error", {
        message: "boom from the browser",
        error: new Error("boom from the browser")
      }))
    JS

    error = nil
    20.times do
      error = SolidErrors::Error.find_by(exception_class: "JavascriptError")
      break if error

      sleep 0.25
    end

    assert error, "expected the browser error to be reported to the error tracker"
    assert_equal "boom from the browser", error.message
  end
end
