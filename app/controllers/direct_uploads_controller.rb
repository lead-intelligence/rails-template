class DirectUploadsController < ActiveStorage::DirectUploadsController
  include Authentication
  include SuperadminAuthentication

  RATE_LIMIT = 30

  allow_unauthenticated_access
  skip_before_action :authenticate_superadmin!
  before_action :authenticate_uploader!
  rate_limit to: RATE_LIMIT, within: 1.minute, with: -> { head :too_many_requests }
  before_action :refuse_oversized_upload

  private

  def authenticate_uploader!
    authenticated? || authenticate_superadmin!
  end

  def refuse_oversized_upload
    head :content_too_large if blob_args[:byte_size].to_i > DirectUpload::MAX_BYTE_SIZE
  end
end
