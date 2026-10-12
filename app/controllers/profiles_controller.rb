class ProfilesController < ApplicationController
  SECURITY_FIELDS = %w[ password password_confirmation password_challenge ].freeze

  rate_limit to: 5, within: 5.minutes, only: :update, by: -> { Current.user.id }, with: -> { redirect_to edit_profile_path, alert: t("profiles.rate_limit") }

  def edit
    @user = Current.user
  end

  def update
    @user = User.find(Current.user.id)
    @user.assign_attributes(profile_params)

    if @user.save(context: :profile)
      EmailConfirmationsMailer.change(@user).deliver_later if @user.unconfirmed_email.present? && profile_params[:unconfirmed_email].present?
      @user.sessions.where.not(id: Current.session.id).delete_all if @user.saved_change_to_password_digest?
      redirect_to edit_profile_url, notice: t("profiles.update.notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params
      .expect(user: [ :name, :avatar, :unconfirmed_email, :password, :password_confirmation, :password_challenge ])
      .reject { |key, value| SECURITY_FIELDS.include?(key) && value.blank? }
  end
end
