require "test_helper"

class ErrorReportJobTest < ActiveJob::TestCase
  URL = "https://peronix.example/errors".freeze

  setup do
    @original = ENV.values_at("PERONIX_ERRORS_URL", "PERONIX_ERRORS_TOKEN")
    ENV["PERONIX_ERRORS_URL"] = URL
    ENV["PERONIX_ERRORS_TOKEN"] = "app-token"
  end

  teardown do
    ENV["PERONIX_ERRORS_URL"], ENV["PERONIX_ERRORS_TOKEN"] = @original
  end

  test "a new error is queued to be told to Peronix once it is saved" do
    assert_enqueued_with(job: ErrorReportJob) { new_error }
  end

  test "an error seen again is not told again, but one that comes back after it was resolved is" do
    error = new_error
    error.update!(resolved_at: Time.current)

    assert_no_enqueued_jobs(only: ErrorReportJob) { error.update!(updated_at: Time.current) }
    assert_enqueued_with(job: ErrorReportJob) { error.update!(resolved_at: nil) }
  end

  test "nothing is queued while Peronix is not set up" do
    ENV["PERONIX_ERRORS_TOKEN"] = nil

    assert_no_enqueued_jobs(only: ErrorReportJob) { new_error }
  end

  test "it sends the error as the feed shows it, with the app's token" do
    error = new_error
    occurrence = error.occurrences.create!(backtrace: "", context: { route: "GET /chats/:id(.:format)" })
    sent = stub_request(:post, URL)
      .with(headers: { "Authorization" => "Bearer app-token", "Content-Type" => "application/json" },
            body: ErrorFeed.entry(occurrence).to_json)
      .to_return(status: 202)

    ErrorReportJob.perform_now(error)

    assert_requested sent
    assert_equal "GET /chats/:id(.:format)", ErrorFeed.entry(occurrence)[:route]
  end

  test "Peronix refusing it is an error, so the job runs again" do
    error = new_error
    error.occurrences.create!(backtrace: "", context: {})
    stub_request(:post, URL).to_return(status: 503)

    assert_raises(PeronixErrors::Error) { ErrorReportJob.new.perform(error) }
  end

  test "an error with no occurrence yet waits for it" do
    assert_raises(ErrorReportJob::NoOccurrenceYet) { ErrorReportJob.new.perform(new_error) }
  end

  private

  def new_error
    SolidErrors::Error.create!(exception_class: "NoMethodError", message: "boom", severity: "error", fingerprint: SecureRandom.hex(32))
  end
end
