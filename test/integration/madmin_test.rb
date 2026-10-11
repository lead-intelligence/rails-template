require "test_helper"

class MadminTest < ActionDispatch::IntegrationTest
  RESOURCE_PATHS = %w[
    /madmin
    /madmin/chats
    /madmin/documents
    /madmin/feedbacks
    /madmin/messages
    /madmin/sessions
    /madmin/users
    /madmin/noticed/notifications
    /madmin/noticed/events
  ].freeze

  setup do
    @original_user = ENV["SUPERADMIN_USER"]
    @original_password = ENV["SUPERADMIN_PASSWORD"]
  end

  teardown do
    ENV["SUPERADMIN_USER"] = @original_user
    ENV["SUPERADMIN_PASSWORD"] = @original_password
  end

  def superadmin_headers
    { "Authorization" => "Basic #{Base64.strict_encode64("superadmin:secret")}" }
  end

  test "requires basic auth credentials" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    get "/madmin"

    assert_response :unauthorized
  end

  test "denies access when no credentials are configured" do
    ENV["SUPERADMIN_USER"] = nil
    ENV["SUPERADMIN_PASSWORD"] = nil

    get "/madmin", headers: superadmin_headers

    assert_response :unauthorized
  end

  test "every panel renders for the superadmin" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    RESOURCE_PATHS.each do |path|
      get path, headers: superadmin_headers

      assert_response :success, "expected #{path} to render for the superadmin"
    end
  end

  test "an index page loads the owner of every row in one query" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"
    create_owned_rows(users(:one))
    baseline = owned_index_queries

    3.times do |index|
      create_owned_rows(User.create!(name: "Owner #{index}", email_address: "owner#{index}@example.com", password: "password"))
    end

    assert_equal baseline, owned_index_queries
  end

  private

  def create_owned_rows(user)
    chat = user.chats.create!(model: "gpt-4o-mini")
    user.documents.create!(title: "Notes", content: "Notes")
    user.feedbacks.create!(message: "Nice", chat: chat)
    user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test")
  end

  def owned_index_queries
    %w[/madmin/chats /madmin/documents /madmin/feedbacks /madmin/sessions].to_h do |path|
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path, headers: superadmin_headers }
      [ path, count ]
    end
  end
end
