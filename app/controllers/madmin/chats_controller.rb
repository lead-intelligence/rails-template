module Madmin
  class ChatsController < Madmin::ResourceController
    private

    def scoped_resources
      super.includes(:user)
    end
  end
end
