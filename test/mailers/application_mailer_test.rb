require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "mail comes from the app's name" do
    email = PasswordsMailer.reset(users(:one))

    assert_equal [ "from@example.com" ], email.from
    assert_equal [ I18n.t("app_name") ], email[:from].display_names
  end
end
