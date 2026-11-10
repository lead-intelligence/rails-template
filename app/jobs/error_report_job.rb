class ErrorReportJob < ApplicationJob
  queue_as :default

  retry_on PeronixErrors::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
    wait: :polynomially_longer, attempts: 10

  def self.report_later(occurrence)
    perform_later(occurrence) if PeronixErrors.configured?
  end

  def perform(occurrence)
    PeronixErrors.report(ErrorFeed.entry(occurrence))
  end
end
