module Madmin
  class FeedbacksController < Madmin::ResourceController
    private

    def scoped_resources
      super.includes(:user)
    end
  end
end
