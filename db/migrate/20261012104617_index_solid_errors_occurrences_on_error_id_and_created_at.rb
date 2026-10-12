class IndexSolidErrorsOccurrencesOnErrorIdAndCreatedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :solid_errors_occurrences, [ :error_id, :created_at ]
  end
end
