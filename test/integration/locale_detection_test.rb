require "test_helper"

class LocaleDetectionTest < ActionDispatch::IntegrationTest
  test "serves Spanish when the browser prefers it" do
    get new_session_url, headers: { "Accept-Language" => "es-ES,es;q=0.9,en;q=0.8" }

    assert_select "h1", "Iniciar sesión"
  end

  test "serves English when the browser prefers it" do
    get new_session_url, headers: { "Accept-Language" => "en-US,en;q=0.9,es;q=0.8" }

    assert_select "h1", "Sign in"
  end

  test "falls back to the default locale (Spanish) without an Accept-Language header" do
    get new_session_url

    assert_select "h1", "Iniciar sesión"
  end

  test "follows the q-values, not the order of the header" do
    get new_session_url, headers: { "Accept-Language" => "en;q=0.1, es;q=0.9" }

    assert_select "h1", I18n.t("sessions.new.title", locale: :es)
  end

  test "matches a language tag in any case" do
    get new_session_url, headers: { "Accept-Language" => "EN-US" }

    assert_select "h1", I18n.t("sessions.new.title", locale: :en)
  end

  test "skips a language the browser marks as not acceptable" do
    get new_session_url, headers: { "Accept-Language" => "fr, -, ,en;q=0" }

    assert_select "h1", I18n.t("sessions.new.title", locale: :es)
  end

  test "skips an empty language range" do
    get new_session_url, headers: { "Accept-Language" => ";q=1, en;q=0.5" }

    assert_select "h1", I18n.t("sessions.new.title", locale: :en)
  end
end
