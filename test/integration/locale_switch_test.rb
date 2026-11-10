require "test_helper"

class LocaleSwitchTest < ActionDispatch::IntegrationTest
  test "a chosen locale wins over the browser's preference" do
    patch locale_url(locale: "en"), headers: { "HTTP_REFERER" => new_session_url }

    assert_redirected_to new_session_url
    get new_session_url, headers: { "Accept-Language" => "es-ES,es;q=0.9" }
    assert_select "h1", I18n.t("sessions.new.title", locale: :en)
  end

  test "ignores a locale the app does not ship" do
    patch locale_url(locale: "fr")

    assert_redirected_to root_url
    get new_session_url
    assert_select "h1", I18n.t("sessions.new.title", locale: :es)
  end

  test "ignores a stored locale the app no longer ships" do
    cookies[:locale] = "fr"

    get new_session_url, headers: { "Accept-Language" => "en" }

    assert_select "h1", I18n.t("sessions.new.title", locale: :en)
  end

  test "never sends the person to another host" do
    patch locale_url(locale: "en"), headers: { "HTTP_REFERER" => "https://evil.example/phish" }

    assert_redirected_to root_url
  end

  test "lists every locale in its own language and marks the current one" do
    get new_session_url, headers: { "Accept-Language" => "en" }

    assert_select "button[lang=en][aria-current=true]", I18n.t("locale_name", locale: :en)
    assert_select "button[lang=es]:not([aria-current=true])", I18n.t("locale_name", locale: :es)
  end

  test "hides the switcher when the app ships one locale" do
    available = I18n.available_locales
    I18n.available_locales = [ :es ]

    get new_session_url

    assert_select "form[action='#{locale_path}']", count: 0
  ensure
    I18n.available_locales = available
  end
end
