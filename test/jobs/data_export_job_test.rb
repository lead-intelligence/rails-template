require "test_helper"

class DataExportJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "attaches the export and emails the user" do
    user = users(:one)

    assert_enqueued_email_with DataExportMailer, :ready, args: [ user ] do
      DataExportJob.perform_now(user)
    end

    assert user.reload.data_export.attached?
    assert_equal "application/zip", user.data_export.content_type
    Zip::File.open_buffer(StringIO.new(user.data_export.download)) do |zip|
      assert_equal user.email_address, JSON.parse(zip.read("data.json"))["user"]["email_address"]
    end
  end
end
