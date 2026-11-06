require "test_helper"

class DirectUploadsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    @original_username = ENV["SUPERADMIN_USER"]
    @original_password = ENV["SUPERADMIN_PASSWORD"]
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"
  end

  teardown do
    ENV["SUPERADMIN_USER"] = @original_username
    ENV["SUPERADMIN_PASSWORD"] = @original_password
  end

  test "refuses an anonymous upload" do
    assert_no_difference("ActiveStorage::Blob.count") do
      post rails_direct_uploads_url, params: blob_params, as: :json
    end

    assert_response :unauthorized
  end

  test "accepts an upload from a signed-in person" do
    sign_in_as users(:one)

    assert_difference("ActiveStorage::Blob.count") do
      post rails_direct_uploads_url, params: blob_params, as: :json
    end

    assert_response :success
    assert response.parsed_body.dig("direct_upload", "url")
  end

  test "accepts an upload from the superadmin, who writes the blog without a session" do
    assert_difference("ActiveStorage::Blob.count") do
      post rails_direct_uploads_url, params: blob_params, headers: superadmin_headers, as: :json
    end

    assert_response :success
  end

  test "refuses a file larger than the upload limit" do
    sign_in_as users(:one)

    assert_no_difference("ActiveStorage::Blob.count") do
      post rails_direct_uploads_url, params: blob_params(byte_size: DirectUpload::MAX_BYTE_SIZE + 1), as: :json
    end

    assert_response :content_too_large
  end

  test "limits how many uploads one client starts per minute" do
    sign_in_as users(:one)

    DirectUploadsController::RATE_LIMIT.times { post rails_direct_uploads_url, params: blob_params, as: :json }
    post rails_direct_uploads_url, params: blob_params, as: :json

    assert_response :too_many_requests
  end

  private

  def blob_params(byte_size: 5)
    { blob: { filename: "hello.txt", byte_size: byte_size, checksum: Digest::MD5.base64digest("hello"), content_type: "text/plain" } }
  end

  def superadmin_headers
    { "Authorization" => "Basic #{Base64.strict_encode64("superadmin:secret")}" }
  end
end
