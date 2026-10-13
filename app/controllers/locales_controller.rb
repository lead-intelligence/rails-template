class LocalesController < ApplicationController
  allow_unauthenticated_access

  def update
    locale = I18n.available_locales.find { |available| available.to_s == params[:locale] }
    cookies.permanent[:locale] = locale.to_s if locale
    redirect_back_or_to root_path, status: :see_other
  end
end
