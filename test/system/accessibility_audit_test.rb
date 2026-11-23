require "application_system_test_case"

class AccessibilityAuditTest < ApplicationSystemTestCase
  test "every page loads axe itself, so an audit never sends it over" do
    page.driver.visit root_url

    assert_equal "object", page.evaluate_script("typeof window.axe")
  end

  test "the audit fails a page with a violation" do
    visit root_url
    page.execute_script("document.body.append(document.createElement('img'))")

    error = assert_raises(Minitest::Assertion) { assert_accessible }

    assert_match "image-alt", error.message
  end
end
