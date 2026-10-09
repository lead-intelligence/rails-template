require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "requires authentication" do
    get edit_profile_url
    assert_redirected_to new_session_url
  end

  test "shows the current user's profile form" do
    sign_in_as users(:one)
    get edit_profile_url
    assert_response :success
  end

  test "updates name and avatar" do
    sign_in_as users(:one)
    assert_no_enqueued_emails do
      patch profile_url, params: { user: { name: "Ada King", avatar: fixture_file_upload("avatar.png", "image/png") } }
    end
    assert_redirected_to edit_profile_url
    assert_equal "Ada King", users(:one).reload.name
    assert users(:one).avatar.attached?

    follow_redirect!
    assert_select ".toast .alert.alert-success", /#{Regexp.escape(I18n.t("profiles.update.notice"))}/
  end

  test "ignores blank password fields" do
    sign_in_as users(:one)
    patch profile_url, params: { user: { name: "Ada King", password: "", password_confirmation: "" } }
    assert_redirected_to edit_profile_url
  end

  test "updates the password when the current password is given" do
    sign_in_as users(:one)
    digest_before = users(:one).password_digest
    patch profile_url, params: { user: { name: "Ada King", password: "newpassword123", password_confirmation: "newpassword123", password_challenge: "password" } }
    assert_redirected_to edit_profile_url
    assert_not_equal digest_before, users(:one).reload.password_digest
  end

  test "refuses a password change without the current password" do
    sign_in_as users(:one)
    digest_before = users(:one).password_digest
    patch profile_url, params: { user: { password: "newpassword123", password_confirmation: "newpassword123", password_challenge: "" } }
    assert_response :unprocessable_entity
    assert_equal digest_before, users(:one).reload.password_digest
    assert_select ".alert-error", count: 1
  end

  test "refuses a password change with a wrong current password" do
    sign_in_as users(:one)
    digest_before = users(:one).password_digest
    patch profile_url, params: { user: { password: "newpassword123", password_confirmation: "newpassword123", password_challenge: "nope" } }
    assert_response :unprocessable_entity
    assert_equal digest_before, users(:one).reload.password_digest
  end

  test "changing the password closes the other sessions" do
    sign_in_as users(:one)
    other = users(:one).sessions.create!(user_agent: "other", ip_address: "127.0.0.1")

    patch profile_url, params: { user: { password: "newpassword123", password_confirmation: "newpassword123", password_challenge: "password" } }

    assert_redirected_to edit_profile_url
    assert_not Session.exists?(other.id)
    assert_equal 1, users(:one).sessions.count
  end

  test "starts an email change and mails the pending address" do
    sign_in_as users(:one)

    assert_enqueued_email_with EmailConfirmationsMailer, :change, args: [ users(:one) ] do
      patch profile_url, params: { user: { unconfirmed_email: "ada-new@example.com", password_challenge: "password" } }
    end

    assert_redirected_to edit_profile_url
    assert_equal "ada@example.com", users(:one).reload.email_address
    assert_equal "ada-new@example.com", users(:one).unconfirmed_email

    follow_redirect!
    assert_select "body", /#{Regexp.escape(I18n.t("profiles.edit.pending_email", email: "ada-new@example.com"))}/
  end

  test "refuses an email change without the current password" do
    sign_in_as users(:one)

    assert_no_enqueued_emails do
      patch profile_url, params: { user: { unconfirmed_email: "ada-new@example.com", password_challenge: "" } }
    end

    assert_response :unprocessable_entity
    assert_nil users(:one).reload.unconfirmed_email
  end

  test "refuses an email change to an address another account owns and mails nobody" do
    sign_in_as users(:one)

    assert_no_enqueued_emails do
      patch profile_url, params: { user: { unconfirmed_email: users(:two).email_address, password_challenge: "password" } }
    end

    assert_response :unprocessable_entity
    assert_nil users(:one).reload.unconfirmed_email
    assert_select ".alert-error", /#{Regexp.escape(users(:one).errors.generate_message(:unconfirmed_email, :taken))}/
  end

  test "re-submitting the same pending address sends the confirmation email again" do
    sign_in_as users(:one)
    users(:one).update!(unconfirmed_email: "ada-new@example.com")

    assert_enqueued_email_with EmailConfirmationsMailer, :change, args: [ users(:one) ] do
      patch profile_url, params: { user: { unconfirmed_email: "ada-new@example.com", password_challenge: "password" } }
    end

    assert_redirected_to edit_profile_url
    assert_equal "ada-new@example.com", users(:one).reload.unconfirmed_email
  end

  test "a blank new email cancels the pending change and mails nothing" do
    sign_in_as users(:one)
    users(:one).update!(unconfirmed_email: "ada-new@example.com")

    assert_no_enqueued_emails do
      patch profile_url, params: { user: { unconfirmed_email: "", password_challenge: "password" } }
    end

    assert_redirected_to edit_profile_url
    assert_nil users(:one).reload.unconfirmed_email
  end

  test "rate limits repeated profile updates" do
    sign_in_as users(:one)
    5.times { patch profile_url, params: { user: { name: "Ada King" } } }

    patch profile_url, params: { user: { name: "Ada Byron" } }

    assert_redirected_to edit_profile_url
    assert_equal I18n.t("profiles.rate_limit"), flash[:alert]
    assert_equal "Ada King", users(:one).reload.name
  end

  test "email_address is not mass-assignable" do
    sign_in_as users(:one)

    patch profile_url, params: { user: { name: "Ada King", email_address: "hijack@example.com" } }

    assert_redirected_to edit_profile_url
    assert_equal "ada@example.com", users(:one).reload.email_address
  end

  test "renders the form again when the update is invalid" do
    sign_in_as users(:one)
    patch profile_url, params: { user: { name: "" } }
    assert_response :unprocessable_entity
  end
end
