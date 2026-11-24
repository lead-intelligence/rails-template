module ErrorHistory
  def self.purge_expired
    SolidErrors::Occurrence.where(created_at: ...SolidErrors.destroy_after.ago).in_batches.delete_all
  end
end
