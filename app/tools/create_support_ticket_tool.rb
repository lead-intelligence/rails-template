class CreateSupportTicketTool < RubyLLM::Tool
  description "Files a refined support ticket with the team once the person's problem or suggestion is understood."

  parameter :title, description: "A short, plain-language title for the ticket"
  parameter :summary, description: "A clear, plain-language summary of the problem or suggestion, written for the app's developer"

  def initialize(chat)
    super()
    @chat = chat
    @user = chat.user
  end

  def execute(title:, summary:)
    feedback = @user.feedbacks.create!(message: "#{title}\n\n#{summary}", context: @chat.ticket_context, chat: @chat)
    photo_count = transfer_pending_photos(feedback)

    confirmation(photo_count)
  end

  private

  def transfer_pending_photos(feedback)
    return 0 unless @chat.pending_photos.attached?

    pending_count = @chat.pending_photos.count
    feedback.photos.attach(@chat.pending_photos.map(&:blob))
    return 0 if feedback.errors.present?

    @chat.pending_photos.detach
    pending_count
  end

  def confirmation(photo_count)
    return "Got it - I've passed this along to the team. Thank you!" unless photo_count.positive?

    "Got it - I've passed this along to the team, including your #{photo_count} #{"photo".pluralize(photo_count)}. Thank you!"
  end
end
