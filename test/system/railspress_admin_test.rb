require "application_system_test_case"

class RailspressAdminTest < ApplicationSystemTestCase
  setup do
    @original_user = ENV["SUPERADMIN_USER"]
    @original_password = ENV["SUPERADMIN_PASSWORD"]
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"
    page.driver.basic_authorize("superadmin", "secret")
  end

  teardown do
    ENV["SUPERADMIN_USER"] = @original_user
    ENV["SUPERADMIN_PASSWORD"] = @original_password
  end

  test "the admin registers the engine's Stimulus controllers under the content security policy" do
    messages = []
    browser = page.driver.browser.page
    browser.command("Log.enable")
    browser.on("Log.entryAdded") { |params| messages << params.dig("entry", "text") }

    page.visit "/railspress/admin/posts/new"
    assert_turbo_ready

    registered = page.evaluate_script(<<~JS)
      window.Stimulus.router.modulesByIdentifier.has("railspress--dropzone")
    JS

    assert registered, "The engine's controllers never registered, so its image and CMS forms are inert."
    assert_empty messages.grep(/script-src/)
  end
end
