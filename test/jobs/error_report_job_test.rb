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

  test "a new error is queued to be told to Peronix with its first occurrence" do
    report "boom"

    assert_enqueued_with(job: ErrorReportJob, args: [ SolidErrors::Occurrence.last ])
  end

  test "an error seen again is not told again, but one that comes back after it was resolved is" do
    report "boom"
    clear_enqueued_jobs

    assert_no_enqueued_jobs(only: ErrorReportJob) { report "boom" }

    SolidErrors::Error.last.update!(resolved_at: Time.current)
    report "boom"
    assert_enqueued_with(job: ErrorReportJob, args: [ SolidErrors::Occurrence.last ])
  end

  test "nothing is queued while Peronix is not set up" do
    ENV["PERONIX_ERRORS_TOKEN"] = nil

    assert_no_enqueued_jobs(only: ErrorReportJob) { report "boom" }
  end

  test "it sends the occurrence as the feed shows it, with the app's token" do
    occurrence = new_error.occurrences.create!(backtrace: "", context: { route: "GET /posts/:id(.:format)" })
    sent = stub_request(:post, URL)
      .with(headers: { "Authorization" => "Bearer app-token", "Content-Type" => "application/json" },
            body: ErrorFeed.entry(occurrence).to_json)
      .to_return(status: 202)

    ErrorReportJob.perform_now(occurrence)

    assert_requested sent
    assert_equal "GET /posts/:id(.:format)", ErrorFeed.entry(occurrence)[:route]
  end

  test "Peronix refusing it is an error, so the job runs again" do
    occurrence = new_error.occurrences.create!(backtrace: "", context: {})
    stub_request(:post, URL).to_return(status: 503)

    assert_raises(PeronixErrors::Error) { ErrorReportJob.new.perform(occurrence) }
  end

  test "Peronix not answering in time is retried later" do
    occurrence = new_error.occurrences.create!(backtrace: "", context: {})
    stub_request(:post, URL).to_timeout

    assert_enqueued_with(job: ErrorReportJob, args: [ occurrence ]) { ErrorReportJob.perform_now(occurrence) }
  end

  private

  def report(message)
    Rails.error.report(StandardError.new(message), handled: true)
  end

  def new_error
    SolidErrors::Error.create!(exception_class: "NoMethodError", message: "boom", severity: "error", fingerprint: SecureRandom.hex(32))
  end
end
