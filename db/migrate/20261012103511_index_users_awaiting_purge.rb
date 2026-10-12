class IndexUsersAwaitingPurge < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :id, where: "confirmed_at IS NULL", name: "index_users_unconfirmed"
    add_index :users, :id, where: "deletion_requested_at IS NOT NULL", name: "index_users_deletion_requested"
  end
end
