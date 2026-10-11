class ActiveSessionsController < ApplicationController
  def index
    @sessions = Current.user.sessions.order(created_at: :desc).load
  end

  def destroy
    target_session = Current.user.sessions.find(params[:id])
    if target_session == Current.session
      terminate_session
      redirect_to new_session_path, notice: t(".notice"), status: :see_other
    else
      target_session.destroy
      redirect_to active_sessions_path, notice: t(".notice"), status: :see_other
    end
  end

  def revoke_others
    Current.user.sessions.where.not(id: Current.session.id).delete_all
    redirect_to active_sessions_path, notice: t(".notice"), status: :see_other
  end
end
