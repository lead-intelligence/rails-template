# A Solid Errors error queues ErrorReportJob when it is new, or comes back
# after it was resolved: Peronix hears of each error once until it is fixed.
module ReportedToPeronix
  extend ActiveSupport::Concern

  included do
    after_commit :report_to_peronix, on: %i[create update], if: :unresolved_again?
  end

  private

  def unresolved_again?
    resolved_at.nil? && (previously_new_record? || saved_change_to_resolved_at?) && PeronixErrors.configured?
  end

  def report_to_peronix
    ErrorReportJob.perform_later(self)
  end
end
