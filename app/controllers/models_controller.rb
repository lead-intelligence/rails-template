class ModelsController < ApplicationController
  include SuperadminAuthentication

  allow_unauthenticated_access

  def index
    @models = RubyLLM.models.chat_models.sort_by { |model| [ model.provider.to_s, model.name.to_s ] }
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
