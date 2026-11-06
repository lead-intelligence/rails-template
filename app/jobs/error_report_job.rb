# Sends a new error to Peronix as the error feed shows it (ErrorFeed.entry).
# Solid Errors saves the error before its occurrence, so a job that finds
# none yet waits for it; one Peronix does not take runs again later.
class ErrorReportJob < ApplicationJob
  NoOccurrenceYet = Class.new(StandardError)

  queue_as :default

  retry_on NoOccurrenceYet, wait: 5.seconds, attempts: 5
  retry_on PeronixErrors::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
    wait: :polynomially_longer, attempts: 10

  def perform(error)
    occurrence = error.occurrences.order(:id).last or raise NoOccurrenceYet, "error #{error.id}"

    PeronixErrors.report(ErrorFeed.entry(occurrence))
  end
end
