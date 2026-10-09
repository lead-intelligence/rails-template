require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "signs in with valid credentials" do
    sign_in_as users(:one)
    assert_redirected_to root_url
    assert cookies[:session_id].present?
  end

  test "rejects invalid credentials" do
    post session_url, params: { email_address: "ada@example.com", password: "wrong" }
    assert_redirected_to new_session_url

    follow_redirect!
    assert_select ".toast .alert.alert-error", /#{Regexp.escape(I18n.t("sessions.create.alert"))}/
  end

  test "rejects a sign-in with a missing password or email" do
    [ { email_address: "ada@example.com" }, { password: "password" }, {} ].each do |params|
      post session_url, params: params
      assert_redirected_to new_session_url
      assert_equal I18n.t("sessions.create.alert"), flash[:alert]
    end
  end

  test "signs out" do
    sign_in_as users(:one)
    delete session_url
    assert_redirected_to new_session_url
    assert cookies[:session_id].blank?
  end

  test "rate limits repeated sign-in attempts" do
    10.times { post session_url, params: { email_address: "ada@example.com", password: "wrong" } }

    post session_url, params: { email_address: "ada@example.com", password: "wrong" }

    assert_redirected_to new_session_url
    assert_equal I18n.t("sessions.rate_limit"), flash[:alert]
  end
end
