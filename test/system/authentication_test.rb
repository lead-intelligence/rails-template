require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "signing up, confirming the email and signing in" do
    visit new_registration_url
    fill_in "user_name", with: "Nueva Usuaria"
    fill_in "user_email_address", with: "nueva@example.com"
    fill_in "user_password", with: "password123"
    fill_in "user_password_confirmation", with: "password123"
    click_button t("registrations.new.sign_up")

    assert_selector ".toast .alert", text: t("registrations.create.notice")

    visit path_from_last_email(%r{http://example\.com/email_confirmations/[\w=-]+})

    assert_selector ".toast .alert", text: t("email_confirmations.show.confirmed")

    fill_in "email_address", with: "nueva@example.com"
    fill_in "password", with: "password123"
    click_button t("sessions.new.sign_in")

    assert_current_path root_path
  end

  test "signing out from the navbar dropdown" do
    sign_in_via_browser(users(:one))

    find(".navbar div[role='button']").click
    click_button t("shared.navbar.sign_out")

    assert_current_path new_session_path
    assert_selector "h1", text: t("sessions.new.title")
  end

  test "resetting a forgotten password" do
    user = users(:one)

    visit new_session_url
    click_link t("sessions.new.forgot_password")
    assert_current_path new_password_path
    fill_in "email_address", with: user.email_address
    click_button t("passwords.new.submit")

    assert_selector ".toast .alert", text: t("passwords.create.notice")

    visit path_from_last_email(%r{http://example\.com/passwords/[\w=-]+/edit})

    fill_in "password", with: "newpassword123"
    fill_in "password_confirmation", with: "newpassword123"
    click_button t("passwords.edit.save")

    assert_selector ".toast .alert", text: t("passwords.update.notice")

    fill_in "email_address", with: user.email_address
    fill_in "password", with: "newpassword123"
    click_button t("sessions.new.sign_in")

    assert_current_path root_path
  end

  private

  def path_from_last_email(pattern)
    body = ActionMailer::Base.deliveries.last.text_part.decoded
    URI.parse(body[pattern]).request_uri
  end
end
