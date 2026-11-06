class FeedbacksController < ApplicationController
  rate_limit to: Feedback::HOURLY_LIMIT, within: 1.hour, only: :create, by: -> { Current.user.id }, with: -> { redirect_to new_feedback_path, alert: t("feedbacks.rate_limit") }

  def new
    @feedback = Current.user.feedbacks.build
  end

  def create
    @feedback = Current.user.feedbacks.build(feedback_params)
    if @feedback.save
      redirect_to root_path, notice: t("feedbacks.create.notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.expect(feedback: [ :message, photos: [] ])
  end
end
