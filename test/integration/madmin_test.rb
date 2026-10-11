require "test_helper"

class MadminTest < ActionDispatch::IntegrationTest
  RESOURCE_PATHS = %w[
    /madmin
    /madmin/chats
    /madmin/documents
    /madmin/feedbacks
    /madmin/messages
    /madmin/sessions
    /madmin/users
    /madmin/noticed/notifications
    /madmin/noticed/events
  ].freeze

  setup do
    @original_user = ENV["SUPERADMIN_USER"]
    @original_password = ENV["SUPERADMIN_PASSWORD"]
  end

  teardown do
    ENV["SUPERADMIN_USER"] = @original_user
    ENV["SUPERADMIN_PASSWORD"] = @original_password
  end

  def superadmin_headers
    { "Authorization" => "Basic #{Base64.strict_encode64("superadmin:secret")}" }
  end

  test "requires basic auth credentials" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    get "/madmin"

    assert_response :unauthorized
  end

  test "denies access when no credentials are configured" do
    ENV["SUPERADMIN_USER"] = nil
    ENV["SUPERADMIN_PASSWORD"] = nil

    get "/madmin", headers: superadmin_headers

    assert_response :unauthorized
  end

  test "every panel renders for the superadmin" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    RESOURCE_PATHS.each do |path|
      get path, headers: superadmin_headers

      assert_response :success, "expected #{path} to render for the superadmin"
    end
  end
end
