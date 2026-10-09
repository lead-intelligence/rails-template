class IndexMessagesForDailyQuota < ActiveRecord::Migration[8.1]
  def change
    add_index :messages, [ :chat_id, :role, :created_at ]
    remove_index :messages, :role
  end
end
