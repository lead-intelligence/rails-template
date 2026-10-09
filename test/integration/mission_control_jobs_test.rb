require "test_helper"

class MissionControlJobsTest < ActionDispatch::IntegrationTest
  setup do
    @orig_user = ENV["SUPERADMIN_USER"]
    @orig_pass = ENV["SUPERADMIN_PASSWORD"]
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"
  end

  teardown do
    ENV["SUPERADMIN_USER"] = @orig_user
    ENV["SUPERADMIN_PASSWORD"] = @orig_pass
  end

  def superadmin_headers
    { "Authorization" => "Basic #{Base64.strict_encode64("superadmin:secret")}" }
  end

  test "jobs dashboard requires superadmin auth" do
    get "/jobs"

    assert_response :unauthorized
  end

  test "jobs dashboard denies access when no credentials are configured" do
    ENV["SUPERADMIN_USER"] = nil
    ENV["SUPERADMIN_PASSWORD"] = nil

    get "/jobs", headers: superadmin_headers

    assert_response :unauthorized
  end

  test "a first visit to the English-only dashboard after a reload keeps the Spanish translations" do
    I18n.backend.reload!
    Rails.application.reloader.prepare!

    get "/jobs", headers: superadmin_headers

    assert_not_equal I18n.t("messages.failure.body", locale: :en), I18n.t("messages.failure.body", locale: :es)
  ensure
    I18n.backend.reload!
    I18n.eager_load!
  end

  test "jobs dashboard is reachable with superadmin credentials" do
    get "/jobs", headers: superadmin_headers

    assert_response :success
  end
end
