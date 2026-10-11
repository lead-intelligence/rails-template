require "application_system_test_case"

class ActiveSessionsTest < ApplicationSystemTestCase
  test "pages through the active sessions" do
    sign_in_via_browser(users(:one))
    ActiveSessionsController::PER_PAGE.times { |index| users(:one).sessions.create!(ip_address: "10.0.0.#{index}", user_agent: "Browser #{index}") }

    visit active_sessions_path
    assert_selector "#sessions li", count: ActiveSessionsController::PER_PAGE

    find("nav.pagy a[aria-label='#{t("pagy.aria_label.next")}']").click

    assert_current_path active_sessions_path(page: 2)
    assert_selector "#sessions li", count: 1
    assert_text t("active_sessions.index.this_device")
  end
end
