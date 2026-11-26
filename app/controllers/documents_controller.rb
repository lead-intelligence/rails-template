class DocumentsController < ApplicationController
  PER_PAGE = 25
  SEARCH_LIMIT = 20
  SAVE_LIMIT = 20

  rate_limit to: SEARCH_LIMIT, within: 1.minute, only: :index, if: -> { params[:q].present? }, by: -> { Current.user.id },
    name: "search", with: -> { redirect_to documents_path, alert: t("documents.rate_limit") }
  rate_limit to: SAVE_LIMIT, within: 1.minute, only: %i[ create update ], by: -> { Current.user.id },
    name: "save", with: -> { redirect_to documents_path, alert: t("documents.rate_limit") }

  def index
    query = params.permit(:q, :page)[:q]
    @documents = search(query) if query.present?
    @pagy, @documents = pagy(listed_documents, limit: PER_PAGE, raise_range_error: true) unless @documents
  end

  def show
    @document = Current.user.documents.find(params[:id])
  end

  def new
    @document = Current.user.documents.build
  end

  def create
    @document = Current.user.documents.build(document_params)
    if @document.save
      redirect_to @document, notice: t("documents.create.notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @document = Current.user.documents.find(params[:id])
  end

  def update
    @document = Current.user.documents.find(params[:id])
    if @document.update(document_params)
      redirect_to @document, notice: t("documents.update.notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Current.user.documents.find(params[:id]).destroy
    redirect_to documents_url, notice: t("documents.destroy.notice")
  end

  private

  def search(query)
    RubyLLM.with_owner(Current.user) do
      Document.where(user: Current.user).select(:id, :title).semantic_search(query)
    end
  rescue RubyLLM::Error => error
    Rails.error.report(error)
    flash.now[:alert] = t("documents.index.search_unavailable")
    nil
  end

  def listed_documents
    Current.user.documents.select(:id, :title).order(updated_at: :desc)
  end

  def document_params
    params.expect(document: [ :title, :content ])
  end
end
