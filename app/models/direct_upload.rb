module DirectUpload
  MAX_BYTE_SIZE = 10.megabytes
  ABANDONED_AFTER = 1.day

  def self.purge_abandoned
    ActiveStorage::Blob.unattached.where(created_at: ..ABANDONED_AFTER.ago).find_each(&:purge_later)
  end
end
