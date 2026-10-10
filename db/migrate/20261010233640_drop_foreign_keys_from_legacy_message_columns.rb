class DropForeignKeysFromLegacyMessageColumns < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :messages, :ruby_llm_tool_calls, column: :tool_call_id
    remove_foreign_key :messages, :ruby_llm_models, column: :model_id
  end
end
