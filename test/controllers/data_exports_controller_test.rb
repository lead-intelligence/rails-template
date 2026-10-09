require "test_helper"

class DataExportsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "create enqueues an export job" do
    sign_in_as users(:one)

    assert_enqueued_with(job: DataExportJob) do
      post data_export_url
    end

    assert_redirected_to edit_profile_url
  end

  test "create rate limits repeated export requests per person" do
    sign_in_as users(:one)
    DataExport::REQUEST_LIMIT.times { post data_export_url }

    assert_no_enqueued_jobs only: DataExportJob do
      post data_export_url
    end

    assert_redirected_to edit_profile_url
    assert_equal I18n.t("data_exports.rate_limit", count: DataExport::REQUEST_LIMIT), flash[:alert]

    delete session_url
    sign_in_as users(:two)

    assert_enqueued_with(job: DataExportJob) { post data_export_url }
  end

  test "create requires authentication" do
    assert_no_enqueued_jobs only: DataExportJob do
      post data_export_url
    end

    assert_redirected_to new_session_url
  end

  test "show redirects to the generated export" do
    user = users(:one)
    user.data_export.attach(io: StringIO.new("zip"), filename: "data-export.zip", content_type: "application/zip")
    sign_in_as user

    get data_export_url

    assert_response :redirect
  end

  test "show purges and reports an expired export" do
    user = users(:one)
    user.data_export.attach(io: StringIO.new("zip"), filename: "data-export.zip", content_type: "application/zip")
    user.data_export.attachment.update_column(:created_at, (DataExport::RETENTION + 1.hour).ago)
    sign_in_as user

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      get data_export_url
    end

    assert_redirected_to edit_profile_url
    assert_equal I18n.t("data_exports.show.expired"), flash[:notice]
  end

  test "show reports when no export is ready yet" do
    sign_in_as users(:one)

    get data_export_url

    assert_redirected_to edit_profile_url
  end

  test "show requires authentication" do
    get data_export_url

    assert_redirected_to new_session_url
  end
end
