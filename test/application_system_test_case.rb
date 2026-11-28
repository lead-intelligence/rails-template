ENV["SKIP_COVERAGE"] ||= "1"
require "test_helper"
require "capybara/cuprite"
require "axe/configuration"

Capybara.default_max_wait_time = 8
Capybara.server = :puma, { Threads: "2:8" }
Capybara.disable_animation = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AccessibilityHelper

  parallelize(threshold: 10)

  driven_by :cuprite, screen_size: [ 1400, 1400 ], options: {
    process_timeout: 30,
    timeout: 15,
    extensions: [ Axe::Configuration.instance.jslib_path ],
    browser_options: { "no-sandbox": nil, "disable-dev-shm-usage": nil }
  }

  ActiveJob::Base.queue_adapter = :inline

  BROWSER_LOCALE = :en

  def t(key, **options)
    I18n.t(key, locale: BROWSER_LOCALE, **options)
  end

  def visit(...)
    super
    assert_turbo_ready
    assert_custom_elements_defined
    assert_accessible
    assert_fits_phone
  end

  def assert_turbo_ready
    assert_selector "body[data-turbo-ready]"
  end

  def assert_custom_elements_defined
    assert_no_selector ":not(:defined)"
  end

  def without_raising_server_errors
    previous = Capybara.raise_server_errors
    Capybara.raise_server_errors = false
    yield
  ensure
    Capybara.current_session.server&.wait_for_pending_requests
    Capybara.current_session.raise_server_error!
    Capybara.raise_server_errors = previous
  end

  def choose_theme(theme)
    find("summary[title='#{t("shared.theme_switcher.label")}']").click
    find("label", text: t("shared.theme_switcher.#{theme}")).click
  end

  # Signs the user in as the app does, with a session and its signed cookie,
  # and opens the signed-in home. The login form has its own tests
  # (authentication_test.rb): going through it in every test took a quarter
  # of the system tests' time (measured on lacaniosa, 2026-11-28).
  def sign_in_via_browser(user)
    session = user.sessions.create!(user_agent: "system test", ip_address: "127.0.0.1")
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session.id
    page.driver.browser.cookies.set(name: "session_id", value: jar[:session_id], domain: Capybara.current_session.server.host)
    visit chats_path
    assert_current_path chats_path
  end
end
