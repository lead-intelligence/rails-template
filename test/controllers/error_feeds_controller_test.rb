require "test_helper"

class ErrorFeedsControllerTest < ActionDispatch::IntegrationTest
  TOKEN = "feed-token"

  setup do
    @original_token = ENV["ERROR_FEED_TOKEN"]
    ENV["ERROR_FEED_TOKEN"] = TOKEN
  end

  teardown do
    ENV["ERROR_FEED_TOKEN"] = @original_token
  end

  test "an app without a token configured answers not found, even to a bearer" do
    ENV["ERROR_FEED_TOKEN"] = nil

    get error_feed_url, headers: bearer(TOKEN)

    assert_response :not_found
  end

  test "a request without a token is unauthorized" do
    get error_feed_url

    assert_response :unauthorized
  end

  test "a request with the wrong token is unauthorized" do
    get error_feed_url, headers: bearer("wrong")

    assert_response :unauthorized
  end

  test "an empty feed keeps the cursor where it was" do
    get error_feed_url, params: { since: 42 }, headers: bearer(TOKEN)

    assert_response :success
    assert_equal({ "occurrences" => [], "next_cursor" => 42, "more" => false }, response.parsed_body)
  end

  test "without a cursor the feed starts from the oldest occurrence" do
    first = record_occurrence
    second = record_occurrence

    feed

    assert_equal [ first.id, second.id ], response.parsed_body["occurrences"].pluck("id")
    assert_equal second.id, response.parsed_body["next_cursor"]
  end

  test "the cursor skips what the watcher has already seen" do
    seen = record_occurrence
    fresh = record_occurrence

    feed since: seen.id

    assert_equal [ fresh.id ], response.parsed_body["occurrences"].pluck("id")
  end

  test "a cursor that is not a whole number is a bad request" do
    [ "abc", "-1", "1.5" ].each do |since|
      get error_feed_url, params: { since: since }, headers: bearer(TOKEN)

      assert_response :bad_request
    end
  end

  test "a page holds at most the page size and says there is more" do
    error = create_error
    rows = Array.new(ErrorFeed::PAGE_SIZE + 1) { { error_id: error.id, backtrace: "", created_at: Time.current, updated_at: Time.current } }
    SolidErrors::Occurrence.insert_all(rows)
    ids = SolidErrors::Occurrence.order(:id).ids

    feed

    body = response.parsed_body
    assert_equal ErrorFeed::PAGE_SIZE, body["occurrences"].size
    assert body["more"]
    assert_equal ids[ErrorFeed::PAGE_SIZE - 1], body["next_cursor"]

    feed since: body["next_cursor"]

    assert_equal [ ids.last ], response.parsed_body["occurrences"].pluck("id")
    assert_not response.parsed_body["more"]
  end

  test "an occurrence carries what the error says about itself" do
    error = create_error(message: "undefined method 'name' for nil", severity: "warning", source: "application.action_dispatch")
    older = record_occurrence(error, created_at: 2.hours.ago)
    newer = record_occurrence(error, context: { "route" => "GET /documents/:id(.:format)" })
    error.update!(resolved_at: Time.current)

    feed since: older.id

    item = response.parsed_body["occurrences"].sole
    assert_equal newer.id, item["id"]
    assert_equal newer.created_at.as_json, item["occurred_at"]
    assert_equal error.fingerprint, item["fingerprint"]
    assert_equal "NoMethodError", item["exception_class"]
    assert_equal "undefined method 'name' for nil", item["message"]
    assert_equal "warning", item["severity"]
    assert_equal "application.action_dispatch", item["source"]
    assert item["resolved"]
    assert_equal error.created_at.as_json, item["first_seen_at"]
    assert_equal newer.created_at.as_json, item["last_seen_at"]
    assert_equal 2, item["occurrences_count"]
    assert_equal "GET /documents/:id(.:format)", item["route"]
  end

  test "an occurrence with no route recorded says so" do
    record_occurrence

    feed

    assert_nil response.parsed_body["occurrences"].sole["route"]
  end

  test "a long message is truncated" do
    record_occurrence(create_error(message: "x" * 5000))

    feed

    assert_equal ErrorFeed::MESSAGE_LENGTH, response.parsed_body["occurrences"].sole["message"].length
  end

  test "the backtrace keeps only the app's own top frames, without the server's paths" do
    app_frames = Array.new(8) { |i| "#{Rails.root}/app/models/user.rb:#{i + 1}:in 'User#name'" }
    backtrace = [ "#{Gem.path.first}/gems/rack-3.0/lib/rack.rb:1:in 'call'", *app_frames, "#{Rails.root}/vendor/thing.rb:1:in 'x'" ]
    record_occurrence(create_error, backtrace: backtrace.join("\n"))

    feed

    frames = response.parsed_body["occurrences"].sole["backtrace"]
    assert_equal ErrorFeed::BACKTRACE_FRAMES, frames.size
    assert_equal "[PROJECT_ROOT]/app/models/user.rb:1:in `User#name'", frames.first
    assert frames.none? { |frame| frame.include?(Rails.root.to_s) }
  end

  test "an occurrence without a backtrace has no frames" do
    record_occurrence(create_error, backtrace: nil)

    feed

    assert_equal [], response.parsed_body["occurrences"].sole["backtrace"]
  end

  test "nothing from the request context leaks into the feed" do
    context = { "user_id" => 4242, "user_agent" => "SecretAgent/1.0", "url" => "https://app.test/passwords/reset-me?token=hunter2",
      "params" => { "password" => "hunter2" }, "cookies" => "session=abc", "controller" => "#<PagesController>" }
    record_occurrence(create_error, context: context)

    feed

    body = response.body
    [ "4242", "SecretAgent", "reset-me", "hunter2", "session=abc", "PagesController" ].each do |secret|
      assert_not_includes body, secret
    end
  end

  test "repeated polling is rate limited" do
    ErrorFeedsController::RATE_LIMIT.times { feed }

    feed

    assert_response :too_many_requests
  end

  private

  def feed(**params)
    get error_feed_url, params: params, headers: bearer(TOKEN)
    assert_response :success unless response.status == 429
  end

  def bearer(token)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(token) }
  end

  def create_error(message: "boom", severity: "error", source: nil)
    SolidErrors::Error.create!(exception_class: "NoMethodError", message: message, severity: severity, source: source,
      fingerprint: SecureRandom.hex(32))
  end

  def record_occurrence(error = create_error, backtrace: "#{Rails.root}/app/models/user.rb:1:in 'User#name'", context: {}, created_at: Time.current)
    error.occurrences.create!(backtrace: backtrace, context: context, created_at: created_at)
  end
end
