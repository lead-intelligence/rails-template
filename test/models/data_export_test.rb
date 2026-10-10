require "test_helper"

class DataExportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "packages the user's records and files into a zip without sensitive columns" do
    user = users(:one)
    user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    chat = user.chats.create!(model: "gpt-4o-mini")
    document = user.documents.create!(title: "My notes", content: "Confidential <b>rich text</b>")
    user.documents.create!(title: "Second", content: "More notes")
    feedback = user.feedbacks.create!(message: "Nice app")
    feedback.photos.attach(io: File.open(file_fixture("avatar.png")), filename: "shot.png", content_type: "image/png")

    entries = zip_entries(export(user))

    data = JSON.parse(entries["data.json"])
    assert_equal user.email_address, data["user"]["email_address"]
    assert_not data["user"].key?("password_digest")
    assert_includes data["chats"].map { |record| record["id"] }, chat.id
    exported_document = data["documents"].find { |record| record["id"] == document.id }
    assert_not exported_document.key?("embedding")
    assert_equal "Confidential rich text", exported_document["content"]
    assert_includes data["feedbacks"].map { |record| record["id"] }, feedback.id

    assert_includes entries.keys, "files/user/avatar/#{user.avatar.attachment.id}/avatar.png"
    assert_includes entries.keys, "files/feedbacks/#{feedback.id}/photos/#{feedback.photos.first.id}/shot.png"
  end

  test "follows the deletion cascade into nested records and their files" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    message = chat.messages.create!(role: :user, content: "My private question")
    message.attachments.attach(io: File.open(file_fixture("avatar.png")), filename: "photo.png", content_type: "image/png")
    tool_call = chat.messages.create!(role: :assistant, content: "").ruby_llm_tool_calls.create!(tool_call_id: "call_1", name: "lookup", arguments: {})

    entries = zip_entries(export(users(:one)))

    data = JSON.parse(entries["data.json"])
    assert_includes data["chats/messages"].map { |record| record["content"] }, "My private question"
    assert_includes data["chats/messages/ruby_llm_tool_calls"].map { |record| record["id"] }, tool_call.id
    assert_includes entries.keys, "files/chats/messages/#{message.id}/attachments/#{message.attachments.first.id}/photo.png"
  end

  test "leaves out the technical messages a support chat hides from the person" do
    chat = users(:one).chats.create!(support: true)
    reply = chat.messages.create!(role: :assistant, content: "Thanks, I've filed this for the team.")
    chat.messages.create!(role: :system, content: "Never mention code.")
    chat.messages.create!(role: :tool, content: "Ticket filed.")
    chat.messages.create!(role: :assistant, content: "").ruby_llm_tool_calls.create!(tool_call_id: "call_1", name: "create_support_ticket", arguments: {})

    data = JSON.parse(zip_entries(export(users(:one)))["data.json"])

    assert_equal [ reply.id ], data["chats/messages"].map { |record| record["id"] }
    assert_empty data["chats/messages/ruby_llm_tool_calls"]
  end

  test "skips a file missing from storage and lists it instead of failing the export" do
    feedback = users(:one).feedbacks.create!(message: "Nice app")
    feedback.photos.attach(io: File.open(file_fixture("avatar.png")), filename: "lost.png", content_type: "image/png")
    feedback.photos.attach(io: File.open(file_fixture("avatar.png")), filename: "kept.png", content_type: "image/png")
    lost, kept = feedback.photos.sort_by(&:id)
    lost.blob.service.delete(lost.blob.key)
    lost_path = "files/feedbacks/#{feedback.id}/photos/#{lost.id}/lost.png"

    entries = zip_entries(export(users(:one)))

    assert_not_includes entries.keys, lost_path
    assert_includes entries.keys, "files/feedbacks/#{feedback.id}/photos/#{kept.id}/kept.png"
    assert_equal [ lost_path ], JSON.parse(entries["data.json"])["missing_files"]
  end

  test "keeps every attachment when two on one record share a filename" do
    feedback = users(:one).feedbacks.create!(message: "Nice app")
    2.times { feedback.photos.attach(io: File.open(file_fixture("avatar.png")), filename: "shot.png", content_type: "image/png") }

    entries = zip_entries(export(users(:one)))

    feedback.photos.each do |photo|
      assert_includes entries.keys, "files/feedbacks/#{feedback.id}/photos/#{photo.id}/shot.png"
    end
  end

  test "encrypted columns are decrypted by the serialization the export uses, and are excludable" do
    ActiveRecord::Encryption.configure(primary_key: "a" * 32, deterministic_key: "b" * 32, key_derivation_salt: "c" * 32)
    ActiveRecord::Base.connection.create_table(:encrypted_probes, force: true) { |t| t.string :secret }
    probe_class = Class.new(ActiveRecord::Base) do
      self.table_name = "encrypted_probes"
      encrypts :secret
    end
    probe = probe_class.create!(secret: "sensitive")

    stored = ActiveRecord::Base.connection.select_value("select secret from encrypted_probes limit 1")
    assert_not_includes stored, "sensitive"
    assert_equal "sensitive", probe.as_json["secret"]
    assert_not probe.as_json(except: [ "secret" ]).key?("secret")
  ensure
    ActiveRecord::Base.connection.drop_table(:encrypted_probes, if_exists: true)
  end

  test "purge_expired removes exports past the retention window and keeps fresh ones" do
    old_user = users(:one)
    old_user.data_export.attach(io: StringIO.new("old"), filename: "old.zip", content_type: "application/zip")
    old_user.data_export.attachment.update_column(:created_at, (DataExport::RETENTION + 1.hour).ago)

    fresh_user = users(:two)
    fresh_user.data_export.attach(io: StringIO.new("fresh"), filename: "fresh.zip", content_type: "application/zip")

    perform_enqueued_jobs { DataExport.purge_expired }

    assert_not old_user.reload.data_export.attached?
    assert fresh_user.reload.data_export.attached?
  end

  test "the query count does not grow with the number of exported records" do
    user = users(:one)
    user.documents.create!(title: "First", content: "Notes")
    user.feedbacks.create!(message: "First")
    user.chats.create!(model: "gpt-4o-mini").messages.create!(role: :user, content: "Hi")
    baseline = queries_during { export(User.find(user.id)) }

    5.times do |index|
      user.chats.create!(model: "gpt-4o-mini").messages.create!(role: :user, content: "Hi #{index}")
      user.documents.create!(title: "Doc #{index}", content: "Notes")
      user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test")
      user.feedbacks.create!(message: "Feedback #{index}")
    end

    assert_equal baseline, queries_during { export(User.find(user.id)) }
  end

  test "stores attached files as they are instead of compressing them again" do
    user = users(:one)
    feedback = user.feedbacks.create!(message: "Nice app")
    feedback.photos.attach(io: File.open(file_fixture("avatar.png")), filename: "shot.png", content_type: "image/png")

    Zip::File.open_buffer(StringIO.new(export(user))) do |zip|
      assert_equal Zip::Entry::STORED, zip.find_entry("files/feedbacks/#{feedback.id}/photos/#{feedback.photos.first.id}/shot.png").compression_method
      assert_equal Zip::Entry::DEFLATED, zip.find_entry("data.json").compression_method
    end
  end

  private

  def export(user)
    StringIO.new.tap { |io| DataExport.new(user).write(io) }.string
  end

  def queries_during(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  def zip_entries(bytes)
    {}.tap do |entries|
      Zip::File.open_buffer(StringIO.new(bytes)) do |zip|
        zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
      end
    end
  end
end
