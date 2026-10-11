module Madmin
  class SessionsController < Madmin::ResourceController
    private

    def scoped_resources
      super.includes(:user)
    end
  end
end
