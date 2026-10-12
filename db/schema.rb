# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_12_104617) do
  create_table "action_push_native_devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "owner_id"
    t.string "owner_type"
    t.string "platform", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_action_push_native_devices_on_owner"
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["name", "created_at"], name: "index_active_storage_attachments_on_name_and_created_at"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.string "name"
    t.text "properties"
    t.datetime "time"
    t.integer "user_id"
    t.integer "visit_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["time"], name: "index_ahoy_events_on_time"
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "browser"
    t.string "device_type"
    t.string "ip"
    t.text "landing_page"
    t.string "os"
    t.text "referrer"
    t.string "referring_domain"
    t.datetime "started_at"
    t.text "user_agent"
    t.integer "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.index ["started_at"], name: "index_ahoy_visits_on_started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "chats", force: :cascade do |t|
    t.boolean "cancelled", default: false, null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.integer "ruby_llm_model_id"
    t.boolean "support", default: false, null: false
    t.json "ticket_context"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["ruby_llm_model_id"], name: "index_chats_on_ruby_llm_model_id"
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "console1984_commands", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "sensitive_access_id"
    t.integer "session_id", null: false
    t.text "statements"
    t.datetime "updated_at", null: false
    t.index ["sensitive_access_id"], name: "index_console1984_commands_on_sensitive_access_id"
    t.index ["session_id", "created_at", "sensitive_access_id"], name: "on_session_and_sensitive_chronologically"
  end

  create_table "console1984_sensitive_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "justification"
    t.integer "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_console1984_sensitive_accesses_on_session_id"
  end

  create_table "console1984_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "reason"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["created_at"], name: "index_console1984_sessions_on_created_at"
    t.index ["user_id", "created_at"], name: "index_console1984_sessions_on_user_id_and_created_at"
  end

  create_table "console1984_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_console1984_users_on_username"
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.binary "embedding"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.integer "chat_id"
    t.json "context"
    t.datetime "created_at", null: false
    t.text "message", null: false
    t.datetime "resolved_at"
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["chat_id"], name: "index_feedbacks_on_chat_id"
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.string "cache_ttl"
    t.boolean "cache_until_here", default: false, null: false
    t.integer "cached_tokens"
    t.integer "chat_id", null: false
    t.json "citations"
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.string "finish_reason"
    t.integer "input_tokens"
    t.integer "model_id"
    t.integer "output_tokens"
    t.json "raw_content"
    t.json "raw_reasoning"
    t.string "role", null: false
    t.json "server_tool_calls"
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.integer "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id", "role", "created_at"], name: "index_messages_on_chat_id_and_role_and_created_at"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.json "params"
    t.bigint "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "railspress_agent_bootstrap_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "created_by_type"
    t.bigint "exchanged_api_key_id"
    t.datetime "expires_at", null: false
    t.string "global_uuid", null: false
    t.string "name", null: false
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "revoke_reason"
    t.datetime "revoked_at"
    t.bigint "revoked_by_id"
    t.string "revoked_by_type"
    t.text "secret_ciphertext", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.string "used_ip"
    t.index ["created_by_type", "created_by_id"], name: "idx_rp_agent_bootstrap_keys_created_by"
    t.index ["exchanged_api_key_id"], name: "index_railspress_agent_bootstrap_keys_on_exchanged_api_key_id"
    t.index ["global_uuid"], name: "index_railspress_agent_bootstrap_keys_on_global_uuid", unique: true
    t.index ["owner_type", "owner_id"], name: "idx_rp_agent_bootstrap_keys_owner"
    t.index ["revoked_by_type", "revoked_by_id"], name: "idx_rp_agent_bootstrap_keys_revoked_by"
    t.index ["token_digest"], name: "index_railspress_agent_bootstrap_keys_on_token_digest", unique: true
    t.index ["token_prefix"], name: "index_railspress_agent_bootstrap_keys_on_token_prefix"
  end

  create_table "railspress_api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "created_by_type"
    t.datetime "expires_at"
    t.string "global_uuid", null: false
    t.datetime "last_used_at"
    t.string "last_used_ip"
    t.string "name", null: false
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "revoke_reason"
    t.datetime "revoked_at"
    t.bigint "revoked_by_id"
    t.string "revoked_by_type"
    t.bigint "rotated_by_id"
    t.string "rotated_by_type"
    t.integer "rotated_from_id"
    t.text "secret_ciphertext", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_type", "created_by_id"], name: "index_railspress_api_keys_on_created_by_type_and_created_by_id"
    t.index ["global_uuid"], name: "index_railspress_api_keys_on_global_uuid", unique: true
    t.index ["owner_type", "owner_id"], name: "index_railspress_api_keys_on_owner_type_and_owner_id"
    t.index ["revoked_by_type", "revoked_by_id"], name: "index_railspress_api_keys_on_revoked_by_type_and_revoked_by_id"
    t.index ["rotated_by_type", "rotated_by_id"], name: "index_railspress_api_keys_on_rotated_by_type_and_rotated_by_id"
    t.index ["rotated_from_id"], name: "index_railspress_api_keys_on_rotated_from_id"
    t.index ["token_digest"], name: "index_railspress_api_keys_on_token_digest", unique: true
    t.index ["token_prefix"], name: "index_railspress_api_keys_on_token_prefix"
  end

  create_table "railspress_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_railspress_categories_on_name", unique: true
    t.index ["slug"], name: "index_railspress_categories_on_slug", unique: true
  end

  create_table "railspress_content_element_versions", force: :cascade do |t|
    t.bigint "author_id"
    t.integer "content_element_id", null: false
    t.datetime "created_at", null: false
    t.text "text_content"
    t.datetime "updated_at", null: false
    t.integer "version_number", null: false
    t.index ["author_id"], name: "index_railspress_content_element_versions_on_author_id"
    t.index ["content_element_id", "version_number"], name: "idx_content_element_versions_unique", unique: true
    t.index ["content_element_id"], name: "idx_on_content_element_id_c4c667c695"
  end

  create_table "railspress_content_elements", force: :cascade do |t|
    t.bigint "author_id"
    t.integer "content_group_id", null: false
    t.integer "content_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "image_hint"
    t.string "name", null: false
    t.integer "position"
    t.boolean "required", default: false, null: false
    t.text "text_content"
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_railspress_content_elements_on_author_id"
    t.index ["content_group_id", "name"], name: "idx_content_elements_unique_name_per_group", unique: true, where: "deleted_at IS NULL"
    t.index ["content_group_id"], name: "index_railspress_content_elements_on_content_group_id"
    t.index ["content_type"], name: "index_railspress_content_elements_on_content_type"
    t.index ["deleted_at"], name: "index_railspress_content_elements_on_deleted_at"
  end

  create_table "railspress_content_groups", force: :cascade do |t|
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_railspress_content_groups_on_author_id"
    t.index ["deleted_at"], name: "index_railspress_content_groups_on_deleted_at"
    t.index ["name"], name: "index_railspress_content_groups_on_name", unique: true
  end

  create_table "railspress_exports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "error_count", default: 0
    t.text "error_messages"
    t.string "export_type", null: false
    t.string "filename"
    t.string "status", default: "pending", null: false
    t.integer "success_count", default: 0
    t.integer "total_count", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["export_type"], name: "index_railspress_exports_on_export_type"
    t.index ["status"], name: "index_railspress_exports_on_status"
    t.index ["user_id"], name: "index_railspress_exports_on_user_id"
  end

  create_table "railspress_focal_points", force: :cascade do |t|
    t.string "attachment_name", null: false
    t.datetime "created_at", null: false
    t.decimal "focal_x", precision: 5, scale: 4, default: "0.5", null: false
    t.decimal "focal_y", precision: 5, scale: 4, default: "0.5", null: false
    t.json "overrides", default: {}
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "attachment_name"], name: "idx_focal_points_record_attachment", unique: true
  end

  create_table "railspress_imports", force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.integer "error_count", default: 0
    t.text "error_messages"
    t.string "filename"
    t.string "import_type", null: false
    t.string "status", default: "pending", null: false
    t.integer "success_count", default: 0
    t.integer "total_count", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["import_type"], name: "index_railspress_imports_on_import_type"
    t.index ["status"], name: "index_railspress_imports_on_status"
    t.index ["user_id"], name: "index_railspress_imports_on_user_id"
  end

  create_table "railspress_posts", force: :cascade do |t|
    t.bigint "author_id"
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.text "meta_description"
    t.string "meta_title"
    t.datetime "published_at"
    t.integer "reading_time"
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_railspress_posts_on_author_id"
    t.index ["category_id"], name: "index_railspress_posts_on_category_id"
    t.index ["published_at"], name: "index_railspress_posts_on_published_at"
    t.index ["slug"], name: "index_railspress_posts_on_slug", unique: true
    t.index ["status"], name: "index_railspress_posts_on_status"
  end

  create_table "railspress_taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.integer "taggable_id", null: false
    t.string "taggable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id", "taggable_type", "taggable_id"], name: "index_taggings_unique", unique: true
    t.index ["tag_id"], name: "index_railspress_taggings_on_tag_id"
    t.index ["taggable_type", "taggable_id"], name: "index_railspress_taggings_on_taggable"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
  end

  create_table "railspress_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_railspress_tags_on_name", unique: true
    t.index ["slug"], name: "index_railspress_tags_on_slug", unique: true
  end

  create_table "ruby_llm_batches", force: :cascade do |t|
    t.string "batch_protocol"
    t.json "chat_ids", default: []
    t.string "chat_type"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "provider", null: false
    t.string "provider_batch_id", null: false
    t.string "raw_status"
    t.json "reported_cost"
    t.json "request_counts"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_batch_id"], name: "index_ruby_llm_batches_on_provider_and_provider_batch_id", unique: true
    t.index ["status"], name: "index_ruby_llm_batches_on_status"
  end

  create_table "ruby_llm_mcp_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data"
    t.string "key", null: false
    t.bigint "owner_id"
    t.string "owner_type"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_ruby_llm_mcp_credentials_on_key", unique: true
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_mcp_credentials_on_owner"
  end

  create_table "ruby_llm_models", force: :cascade do |t|
    t.json "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.json "metadata", default: {}
    t.json "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.json "pricing", default: {}
    t.string "provider", null: false
    t.datetime "unlisted_at"
    t.datetime "updated_at", null: false
    t.index ["family"], name: "index_ruby_llm_models_on_family"
    t.index ["provider", "model_id"], name: "index_ruby_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ruby_llm_models_on_provider"
  end

  create_table "ruby_llm_provider_files", force: :cascade do |t|
    t.string "account", null: false
    t.string "blob_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.text "file_id", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_key", "provider", "account"], name: "index_ruby_llm_provider_files_uniqueness", unique: true
  end

  create_table "ruby_llm_tool_calls", force: :cascade do |t|
    t.string "approval"
    t.json "arguments", default: {}
    t.datetime "created_at", null: false
    t.json "mcp_result"
    t.json "mcp_state"
    t.integer "message_id", null: false
    t.string "message_type", null: false
    t.string "name", null: false
    t.boolean "remote", default: false, null: false
    t.integer "result_id"
    t.string "result_type"
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_type", "message_id"], name: "index_ruby_llm_tool_calls_on_message_type_and_message_id"
    t.index ["name"], name: "index_ruby_llm_tool_calls_on_name"
    t.index ["result_type", "result_id"], name: "index_ruby_llm_tool_calls_on_result_type_and_result_id"
    t.index ["tool_call_id"], name: "index_ruby_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "ruby_llm_usages", force: :cascade do |t|
    t.decimal "cache_read_cost", precision: 16, scale: 10
    t.integer "cache_read_tokens"
    t.decimal "cache_write_cost", precision: 16, scale: 10
    t.integer "cache_write_tokens"
    t.integer "chat_id"
    t.string "chat_type"
    t.datetime "created_at", null: false
    t.decimal "input_cost", precision: 16, scale: 10
    t.integer "input_tokens"
    t.integer "message_id"
    t.string "message_type"
    t.string "model", null: false
    t.string "operation", null: false
    t.decimal "output_cost", precision: 16, scale: 10
    t.integer "output_tokens"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "provider", null: false
    t.json "server_tool_use"
    t.string "status", null: false
    t.decimal "thinking_cost", precision: 16, scale: 10
    t.integer "thinking_tokens"
    t.decimal "total_cost", precision: 16, scale: 10
    t.datetime "updated_at", null: false
    t.index ["chat_type", "chat_id"], name: "index_ruby_llm_usages_on_chat_type_and_chat_id"
    t.index ["message_type", "message_id"], name: "index_ruby_llm_usages_on_message_type_and_message_id"
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_usages_on_owner"
    t.index ["status"], name: "index_ruby_llm_usages_on_status"
    t.check_constraint "operation IN ('chat', 'embedding', 'moderation', 'image', 'speech', 'transcription', 'ocr', 'rerank', 'judgment', 'video', 'research')"
    t.check_constraint "status IN ('pending', 'succeeded', 'failed', 'cancelled')"
  end

  create_table "ruby_llm_v2_backfills", id: false, force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.integer "last_id"
    t.string "task", null: false
    t.index ["task"], name: "index_ruby_llm_v2_backfills_on_task", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_errors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "exception_class", null: false
    t.string "fingerprint", limit: 64, null: false
    t.text "message", null: false
    t.datetime "resolved_at"
    t.text "severity", null: false
    t.text "source"
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "index_solid_errors_on_fingerprint", unique: true
    t.index ["resolved_at"], name: "index_solid_errors_on_resolved_at"
  end

  create_table "solid_errors_occurrences", force: :cascade do |t|
    t.text "backtrace"
    t.json "context"
    t.datetime "created_at", null: false
    t.integer "error_id", null: false
    t.datetime "updated_at", null: false
    t.index ["error_id", "created_at"], name: "index_solid_errors_occurrences_on_error_id_and_created_at"
    t.index ["error_id"], name: "index_solid_errors_occurrences_on_error_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "deletion_requested_at"
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["id"], name: "index_users_deletion_requested", where: "deletion_requested_at IS NOT NULL"
    t.index ["id"], name: "index_users_unconfirmed", where: "confirmed_at IS NULL"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chats", "ruby_llm_models"
  add_foreign_key "chats", "users"
  add_foreign_key "documents", "users"
  add_foreign_key "feedbacks", "chats"
  add_foreign_key "feedbacks", "users"
  add_foreign_key "messages", "chats"
  add_foreign_key "railspress_content_element_versions", "railspress_content_elements", column: "content_element_id"
  add_foreign_key "railspress_content_elements", "railspress_content_groups", column: "content_group_id"
  add_foreign_key "railspress_posts", "railspress_categories", column: "category_id"
  add_foreign_key "railspress_taggings", "railspress_tags", column: "tag_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_errors_occurrences", "solid_errors", column: "error_id"
end
