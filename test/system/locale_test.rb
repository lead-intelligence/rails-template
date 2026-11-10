require "application_system_test_case"

class LocaleTest < ApplicationSystemTestCase
  test "switches the interface to another language and keeps it" do
    visit new_session_url

    find("summary[title='#{t("shared.locale_switcher.label")}']").click
    click_button I18n.t("locale_name", locale: :es)

    assert_selector "h1", text: I18n.t("sessions.new.title", locale: :es)
    assert_selector "html[lang=es]"

    refresh
    assert_selector "h1", text: I18n.t("sessions.new.title", locale: :es)
  end
end
