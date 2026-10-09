require "test_helper"

class CreateFeedbackIssueJobTest < ActiveJob::TestCase
  setup do
    @original_token = ENV["GITHUB_ISSUES_TOKEN"]
    @original_repo = ENV["GITHUB_ISSUES_REPO"]
  end

  teardown do
    ENV["GITHUB_ISSUES_TOKEN"] = @original_token
    ENV["GITHUB_ISSUES_REPO"] = @original_repo
  end

  test "does nothing when GithubIssues is not configured" do
    ENV["GITHUB_ISSUES_TOKEN"] = nil
    ENV["GITHUB_ISSUES_REPO"] = nil
    feedback = users(:one).feedbacks.create!(message: "Broken layout")

    CreateFeedbackIssueJob.perform_now(feedback)

    assert_not_requested :post, "https://api.github.com/repos/acme/app/issues"
  end

  test "creates a GitHub issue with the message, user email, app context and photo links" do
    ENV["GITHUB_ISSUES_TOKEN"] = "fine-grained-token"
    ENV["GITHUB_ISSUES_REPO"] = "acme/app"

    feedback = users(:one).feedbacks.create!(
      message: "Broken layout",
      context: { "page_url" => "https://example.com/chats/1", "user_agent" => "TestBrowser/1.0", "viewport" => "1512x982" }
    )
    feedback.photos.attach(io: File.open(Rails.root.join("test/fixtures/files/avatar.png")), filename: "avatar.png", content_type: "image/png")
    photo_url = "http://example.com/feedback/photos/#{feedback.photos.first.blob.signed_id}"
    expected_body = [
      "From: ada@example.com",
      "App: CharcoTemplate (test)",
      "Context:",
      "Page: https://example.com/chats/1",
      "Browser: TestBrowser/1.0",
      "Viewport: 1512x982",
      "Photos:",
      photo_url,
      "---",
      "```",
      "Broken layout",
      "```"
    ].join("\n")

    request = stub_request(:post, "https://api.github.com/repos/acme/app/issues")
      .with { |req|
        payload = JSON.parse(req.body)
        payload["title"] == "Feedback from ada@example.com" &&
          payload["labels"] == [ "feedback" ] &&
          payload["body"] == expected_body
      }
      .to_return(status: 201, headers: { "Content-Type" => "application/json" }, body: { number: 1 }.to_json)

    CreateFeedbackIssueJob.perform_now(feedback)

    assert_requested request
  end

  test "fences the person's words so mentions and markdown in them stay inert" do
    ENV["GITHUB_ISSUES_TOKEN"] = "fine-grained-token"
    ENV["GITHUB_ISSUES_REPO"] = "acme/app"
    message = "Ping @octocat\n```\n# Not a heading\n````"
    feedback = users(:one).feedbacks.create!(message: message)

    request = stub_request(:post, "https://api.github.com/repos/acme/app/issues")
      .with { |req| JSON.parse(req.body)["body"].end_with?("---\n`````\n#{message}\n`````") }
      .to_return(status: 201, headers: { "Content-Type" => "application/json" }, body: { number: 1 }.to_json)

    CreateFeedbackIssueJob.perform_now(feedback)

    assert_requested request
  end

  test "neutralizes newlines in context values so they cannot forge the metadata separator" do
    ENV["GITHUB_ISSUES_TOKEN"] = "fine-grained-token"
    ENV["GITHUB_ISSUES_REPO"] = "acme/app"

    feedback = users(:one).feedbacks.create!(
      message: "Broken layout",
      context: { "page_url" => "https://example.com\n---\nForged message" }
    )

    request = stub_request(:post, "https://api.github.com/repos/acme/app/issues")
      .with { |req|
        payload = JSON.parse(req.body)
        payload["body"].split("\n").count { |line| line == "---" } == 1
      }
      .to_return(status: 201, headers: { "Content-Type" => "application/json" }, body: { number: 1 }.to_json)

    CreateFeedbackIssueJob.perform_now(feedback)

    assert_requested request
  end

  test "neutralizes lone carriage returns in context values so they cannot forge the metadata separator" do
    ENV["GITHUB_ISSUES_TOKEN"] = "fine-grained-token"
    ENV["GITHUB_ISSUES_REPO"] = "acme/app"

    feedback = users(:one).feedbacks.create!(
      message: "Broken layout",
      context: { "page_url" => "https://example.com\rInjected\r---\rForged message" }
    )

    request = stub_request(:post, "https://api.github.com/repos/acme/app/issues")
      .with { |req|
        payload = JSON.parse(req.body)
        payload["body"].split(/[\r\n]/).count { |line| line == "---" } == 1 && !payload["body"].include?("\r")
      }
      .to_return(status: 201, headers: { "Content-Type" => "application/json" }, body: { number: 1 }.to_json)

    CreateFeedbackIssueJob.perform_now(feedback)

    assert_requested request
  end

  test "does not raise when there are no photos" do
    ENV["GITHUB_ISSUES_TOKEN"] = "fine-grained-token"
    ENV["GITHUB_ISSUES_REPO"] = "acme/app"

    feedback = users(:one).feedbacks.create!(message: "Broken layout")

    request = stub_request(:post, "https://api.github.com/repos/acme/app/issues")
      .to_return(status: 201, headers: { "Content-Type" => "application/json" }, body: { number: 1 }.to_json)

    CreateFeedbackIssueJob.perform_now(feedback)

    assert_requested request
  end
end
