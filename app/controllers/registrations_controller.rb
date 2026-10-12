class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_registration_path, alert: t("registrations.rate_limit") }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    if @user.save
      EmailConfirmationsMailer.confirm(@user).deliver_later
      redirect_to new_session_path, notice: t("registrations.create.notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if params[:confirmation].to_s.strip == t("registrations.destroy.confirmation_phrase") && Current.user.authenticate(params[:password])
      user = Current.user
      terminate_session
      user.request_deletion!
      redirect_to new_session_path, notice: t("registrations.destroy.notice")
    else
      redirect_to edit_profile_path, alert: t("registrations.destroy.error")
    end
  end

  private

  def registration_params
    params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
  end
end
