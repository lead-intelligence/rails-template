require "test_helper"

class AtelierEntriesControllerTest < ActionDispatch::IntegrationTest
  include AtelierTokenHelper

  test "the helper builds a token exactly as the contract says" do
    assert_equal "eyJlbWFpbCI6ImFkYUBleGFtcGxlLmNvbSIsImV4cCI6NDEwMjQ0NDgwMH0." \
      "096b99ae9132ff41b29127140b56b32e7c7d679b03b2a8860abcba0f0dcef5d4",
      atelier_token(email: "ada@example.com", exp: 4102444800, key: "test-enter-key")
  end

  test "a valid token signs the user in with a new session and goes to the root" do
    with_atelier_enter_key do
      assert_difference -> { users(:one).sessions.count }, 1 do
        get atelier_enter_url(token: atelier_token(email: users(:one).email_address))
      end

      assert_redirected_to root_url
      assert cookies[:session_id].present?
    end
  end

  test "refuses an expired, forged, malformed or unknown token, and signs nobody in" do
    with_atelier_enter_key do
      [
        atelier_token(email: users(:one).email_address, exp: 1.second.ago.to_i),
        atelier_token(email: users(:one).email_address, key: "another-key"),
        atelier_token(email: "nobody@example.com"),
        "#{Base64.urlsafe_encode64("[1]", padding: false)}.#{OpenSSL::HMAC.hexdigest("SHA256", "test-enter-key", Base64.urlsafe_encode64("[1]", padding: false))}",
        "not-base64!.#{OpenSSL::HMAC.hexdigest("SHA256", "test-enter-key", "not-base64!")}",
        "bm90IGpzb24.#{OpenSSL::HMAC.hexdigest("SHA256", "test-enter-key", "bm90IGpzb24")}",
        "no-signature",
        ""
      ].each do |token|
        assert_no_difference("Session.count") { get atelier_enter_url(token: token) }

        assert_redirected_to new_session_url
        assert_equal I18n.t("atelier_entries.show.alert"), flash[:alert]
      end

      assert_no_difference("Session.count") { get atelier_enter_url }
      assert_redirected_to new_session_url
    end
  end

  test "refuses an account that cannot sign in with its password either" do
    users(:one).update!(confirmed_at: nil)
    users(:two).update!(deletion_requested_at: Time.current)

    with_atelier_enter_key do
      [ users(:one), users(:two) ].each do |user|
        assert_no_difference("Session.count") { get atelier_enter_url(token: atelier_token(email: user.email_address)) }
        assert_redirected_to new_session_url
      end
    end
  end

  test "the token never reaches the log" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("token" => "a.b")["token"]
  end

  test "the link does not exist without ATELIER_ENTER_KEY" do
    token = with_atelier_enter_key { atelier_token(email: users(:one).email_address) }

    with_atelier_enter_key(nil) do
      assert_no_difference("Session.count") { get atelier_enter_url(token: token) }
      assert_response :not_found
    end
  end
end
