ENV["SKIP_COVERAGE"] ||= "1"
require "test_helper"
require "capybara/cuprite"

Capybara.default_max_wait_time = 8
Capybara.server = :puma, { Threads: "2:8" }
Capybara.disable_animation = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AccessibilityHelper

  parallelize(threshold: 10)

  driven_by :cuprite, screen_size: [ 1400, 1400 ], options: {
    process_timeout: 30,
    timeout: 15,
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
    assert_accessible
  end

  def assert_turbo_ready
    assert_selector "body[data-turbo-ready]"
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

  def sign_in_via_browser(user)
    visit new_session_url
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button t("sessions.new.sign_in")
    assert_current_path root_path
    assert_turbo_ready
  end
end
