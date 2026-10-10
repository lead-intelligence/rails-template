class ModelsController < ApplicationController
  include SuperadminAuthentication

  allow_unauthenticated_access

  def index
    @models = available_chat_models
  end

  def show
    @model = RubyLLM.models.find(params[:id])
  rescue RubyLLM::ModelNotFoundError
    raise ActiveRecord::RecordNotFound
  end

  def refresh
    RubyLLM.models.refresh
    redirect_to models_path, notice: t("models.refresh.notice")
  end
end
