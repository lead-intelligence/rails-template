require "test_helper"

class EmailConfirmationsMailerTest < ActionMailer::TestCase
  include ActionView::Helpers::DateHelper
  test "confirm addresses the user and includes a confirmation link" do
    user = User.create!(name: "Unconf", email_address: "mailer@example.com", password: "password1234")

    email = EmailConfirmationsMailer.confirm(user)

    assert_equal [ user.email_address ], email.to
    assert_equal I18n.t("email_confirmations_mailer.confirm.subject"), email.subject
    assert_match %r{http://example\.com/email_confirmations/[\w=-]+}, email.text_part.decoded

    retention = I18n.t("email_confirmations_mailer.confirm.retention", duration: distance_of_time_in_words(0, User::UNCONFIRMED_RETENTION))
    assert_includes email.html_part.decoded, retention
    assert_includes email.text_part.decoded, retention
  end

  test "change addresses the pending email and includes an email change link" do
    user = users(:one)
    user.update!(unconfirmed_email: "ada-new@example.com")

    email = EmailConfirmationsMailer.change(user)

    assert_equal [ "ada-new@example.com" ], email.to
    assert_equal I18n.t("email_confirmations_mailer.change.subject"), email.subject
    assert_match %r{http://example\.com/email_changes/[\w=-]+}, email.text_part.decoded
  end

  test "change sends nothing once the pending email is cancelled" do
    user = users(:one)
    user.update!(unconfirmed_email: "ada-new@example.com")
    EmailConfirmationsMailer.change(user).deliver_later
    user.update!(unconfirmed_email: nil)

    assert_no_emails { perform_enqueued_jobs }
  end

  test "a mail for an account deleted before it is sent is dropped" do
    user = User.create!(name: "Gone", email_address: "gone@example.com", password: "password1234")
    EmailConfirmationsMailer.confirm(user).deliver_later
    user.destroy!

    assert_no_emails { perform_enqueued_jobs }
  end
end
