class ErrorFeed
  PAGE_SIZE = 100
  MESSAGE_LENGTH = 500
  BACKTRACE_FRAMES = 5

  def initialize(since:)
    @since = since
  end

  def page
    occurrences = SolidErrors::Occurrence.includes(:error).where(id: (@since + 1)..).order(:id).limit(PAGE_SIZE + 1).to_a
    more = occurrences.size > PAGE_SIZE
    occurrences = occurrences.first(PAGE_SIZE)
    stats = stats_for(occurrences.map(&:error_id).uniq)

    {
      occurrences: occurrences.map { |occurrence| entry(occurrence, stats.fetch(occurrence.error_id)) },
      next_cursor: occurrences.last&.id || @since,
      more: more
    }
  end

  private

  def stats_for(error_ids)
    scope = SolidErrors::Occurrence.where(error_id: error_ids).group(:error_id)
    counts = scope.count
    scope.maximum(:created_at).to_h { |error_id, last_seen_at| [ error_id, { count: counts[error_id], last_seen_at: last_seen_at } ] }
  end

  def entry(occurrence, stats)
    error = occurrence.error

    {
      id: occurrence.id,
      occurred_at: occurrence.created_at,
      fingerprint: error.fingerprint,
      exception_class: error.exception_class,
      message: error.message.truncate(MESSAGE_LENGTH),
      severity: error.severity,
      source: error.source,
      resolved: error.resolved?,
      first_seen_at: error.created_at,
      last_seen_at: stats[:last_seen_at],
      occurrences_count: stats[:count],
      backtrace: app_frames(occurrence),
      route: occurrence.context.to_h["route"]
    }
  end

  def app_frames(occurrence)
    SolidErrors::Backtrace.parse(occurrence.backtrace.to_s.split("\n")).application_lines.first(BACKTRACE_FRAMES).map(&:to_s)
  end
end
