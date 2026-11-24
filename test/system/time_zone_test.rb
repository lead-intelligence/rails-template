require "application_system_test_case"

class TimeZoneTest < ApplicationSystemTestCase
  test "remembers the zone the browser runs in" do
    page.driver.browser.page.command("Emulation.setTimezoneOverride", timezoneId: "America/Argentina/Buenos_Aires")
    sign_in_via_browser users(:one)

    visit chats_url

    browser_zone = page.evaluate_script("Intl.DateTimeFormat().resolvedOptions().timeZone")
    assert_equal ActiveSupport::TimeZone["America/Argentina/Buenos_Aires"].utc_offset, ActiveSupport::TimeZone[browser_zone].utc_offset
    assert_equal browser_zone, users(:one).reload.time_zone
  end
end
