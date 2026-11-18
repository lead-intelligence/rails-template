class AtelierEntriesController < ApplicationController
  allow_unauthenticated_access

  def show
    if (user = User.from_atelier_token(params[:token], key: ENV.fetch("ATELIER_ENTER_KEY")))
      start_new_session_for user
      redirect_to root_path
    else
      redirect_to new_session_path, alert: t(".alert")
    end
  end
end
