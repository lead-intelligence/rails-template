class PagesController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_to_signed_in_home, only: :home

  def home
  end
end
