require "test_helper"

class DirectUploadTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "purges the uploads nobody attached within the window" do
    abandoned = create_blob(created_at: (DirectUpload::ABANDONED_AFTER + 1.hour).ago)
    recent = create_blob(created_at: 1.hour.ago)
    attached = create_blob(created_at: (DirectUpload::ABANDONED_AFTER + 1.hour).ago)
    users(:one).avatar.attach(attached)

    perform_enqueued_jobs { DirectUpload.purge_abandoned }

    assert_not ActiveStorage::Blob.exists?(abandoned.id)
    assert ActiveStorage::Blob.exists?(recent.id)
    assert ActiveStorage::Blob.exists?(attached.id)
  end

  private

  def create_blob(created_at:)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(file_fixture("avatar.png").binread), filename: "avatar.png", content_type: "image/png").tap do |blob|
      blob.update_column(:created_at, created_at)
    end
  end
end
