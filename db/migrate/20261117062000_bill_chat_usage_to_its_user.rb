class BillChatUsageToItsUser < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE ruby_llm_usages
      SET owner_type = 'User', owner_id = (SELECT chats.user_id FROM chats WHERE chats.id = ruby_llm_usages.chat_id)
      WHERE chat_type = 'Chat' AND owner_id IS NULL
    SQL
  end
end
