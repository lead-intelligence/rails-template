class CreateFeedbackIssueJob < ApplicationJob
  queue_as :default

  CONTEXT_LABELS = { "page_url" => "Page", "user_agent" => "Browser", "viewport" => "Viewport" }.freeze

  def perform(feedback)
    return unless GithubIssues.configured?

    GithubIssues.create(title: title_for(feedback), body: body_for(feedback), labels: [ "feedback" ])
  end

  private

  def title_for(feedback)
    "Feedback from #{feedback.user.email_address}"
  end

  def body_for(feedback)
    lines = [
      "From: #{feedback.user.email_address}",
      "App: #{Rails.application.class.module_parent_name} (#{Rails.env})"
    ]

    if feedback.context.present?
      lines << "Context:"
      feedback.context.each { |key, value| lines << "#{CONTEXT_LABELS.fetch(key, key)}: #{value.to_s.gsub(/[\r\n]+/, " ")}" }
    end

    if feedback.photos.attached?
      lines << "Photos:"
      feedback.photos.each { |photo| lines << photo_url(photo) }
    end

    lines << "---"
    lines.concat(fenced(feedback.message))

    lines.join("\n")
  end

  def fenced(text)
    fence = "`" * [ 3, text.scan(/`+/).map(&:length).max.to_i + 1 ].max
    [ fence, text, fence ]
  end

  def photo_url(photo)
    Rails.application.routes.url_helpers.feedback_photo_url(
      signed_id: photo.blob.signed_id,
      **Rails.application.config.action_mailer.default_url_options
    )
  end
end
