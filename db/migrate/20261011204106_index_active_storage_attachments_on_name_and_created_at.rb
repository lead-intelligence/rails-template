class IndexActiveStorageAttachmentsOnNameAndCreatedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :active_storage_attachments, [ :name, :created_at ]
  end
end
