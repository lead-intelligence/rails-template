require "application_system_test_case"

class NotificationsTest < ApplicationSystemTestCase
  test "the bell shows an unread badge, lists recent notifications, and marks them read" do
    sign_in_via_browser(users(:one))

    TestNotifier.deliver(users(:one))
    visit root_path

    find("[aria-label='Notifications']").click
    assert_selector ".indicator .badge-primary", text: "1"
    assert_text "Test notification"

    click_button t("notifications.index.mark_all_read")

    assert_no_selector ".indicator .badge-primary"
  end

  test "the dropdown stays open after the bell loses browser focus" do
    sign_in_via_browser(users(:one))

    TestNotifier.deliver(users(:one))
    visit root_path

    find("[aria-label='Notifications']").click
    page.execute_script("document.activeElement.blur()")

    assert_text "Test notification"
  end

  test "clicking outside the dropdown closes it" do
    sign_in_via_browser(users(:one))

    TestNotifier.deliver(users(:one))
    visit root_path

    find("[aria-label='Notifications']").click
    assert_text "Test notification"

    find("body").click

    assert_no_text "Test notification"
  end

  test "pages through the notifications" do
    sign_in_via_browser(users(:one))
    (NotificationsController::PER_PAGE + 1).times { TestNotifier.deliver(users(:one)) }

    visit notifications_path
    assert_selector "#notification_list li", count: NotificationsController::PER_PAGE

    find("nav.pagy a[aria-label='#{t("pagy.aria_label.next")}']").click

    assert_current_path notifications_path(page: 2)
    assert_selector "#notification_list li", count: 1
    assert_selector "nav.pagy a[aria-current='page']", text: "2"
  end

  test "shows a designed empty state when there are no notifications" do
    sign_in_via_browser(users(:one))

    find("[aria-label='Notifications']").click

    assert_text t("shared.notification_bell.empty")
  end
end
