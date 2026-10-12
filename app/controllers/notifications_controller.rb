class NotificationsController < ApplicationController
  PER_PAGE = 25

  def index
    @pagy, @notifications = pagy(Current.user.notifications.newest_first.includes(:event), limit: PER_PAGE, raise_range_error: true)
    @notifications.load
  end

  def mark_all_read
    Current.user.notifications.unread.mark_as_read
    redirect_back_or_to notifications_path
  end
end
