class IndexSessionsOnUpdatedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :sessions, :updated_at
  end
end
