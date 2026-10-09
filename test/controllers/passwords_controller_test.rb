require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice I18n.t("passwords.create.notice")
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice I18n.t("passwords.create.notice")
  end

  test "rate limits repeated password reset requests" do
    10.times { post passwords_path, params: { email_address: "missing-user@example.com" } }

    post passwords_path, params: { email_address: "missing-user@example.com" }

    assert_redirected_to new_password_path
    assert_equal I18n.t("passwords.rate_limit"), flash[:alert]
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice I18n.t("passwords.invalid_token")
  end

  test "update" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "newpassword123", password_confirmation: "newpassword123" }
      assert_redirected_to new_session_path
    end

    follow_redirect!
    assert_notice I18n.t("passwords.update.notice")
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_notice I18n.t("passwords.update.alert")
  end

  test "update with a blank password changes nothing and keeps the sessions" do
    token = @user.password_reset_token
    @user.sessions.create!

    assert_no_changes -> { [ @user.reload.password_digest, @user.sessions.count ] } do
      put password_path(token), params: { password: "", password_confirmation: "" }
      assert_redirected_to edit_password_path(token)
    end
    assert_equal I18n.t("passwords.update.alert"), flash[:alert]

    get edit_password_path(token)
    assert_response :success
  end

  private
    def assert_notice(text)
      assert_select "div", /#{Regexp.escape(text)}/
    end
end
