require "test_helper"

class SolidErrorsTest < ActionDispatch::IntegrationTest
  setup do
    @original_user = ENV["SUPERADMIN_USER"]
    @original_password = ENV["SUPERADMIN_PASSWORD"]
  end

  teardown do
    ENV["SUPERADMIN_USER"] = @original_user
    ENV["SUPERADMIN_PASSWORD"] = @original_password
  end

  test "reported errors are persisted as SolidErrors::Error records" do
    assert_difference "SolidErrors::Error.count", 1 do
      Rails.error.report(StandardError.new("boom"), handled: true)
    end
  end

  test "resolved errors are destroyed after 30 days" do
    assert_equal 30.days, SolidErrors.destroy_after
  end

  test "dashboard requires basic auth credentials" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    get "/errors"

    assert_response :unauthorized
  end

  test "dashboard denies access when no credentials are configured" do
    ENV["SUPERADMIN_USER"] = nil
    ENV["SUPERADMIN_PASSWORD"] = nil

    get "/errors", headers: { "Authorization" => "Basic #{Base64.strict_encode64("superadmin:secret")}" }

    assert_response :unauthorized
  end

  test "dashboard is reachable with the configured superadmin credentials" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    get "/errors", headers: { "Authorization" => "Basic #{Base64.strict_encode64("superadmin:secret")}" }

    assert_response :success
  end
end
