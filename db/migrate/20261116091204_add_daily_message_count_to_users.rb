class AddDailyMessageCountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :messages_sent_on, :date
    add_column :users, :messages_sent_count, :integer, null: false, default: 0
  end
end
