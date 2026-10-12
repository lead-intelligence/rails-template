class BlogController < ApplicationController
  PER_PAGE = 10

  allow_unauthenticated_access

  def index
    scope = Railspress::Post.published
                            .includes(:category, :tags)
                            .with_attached_header_image
                            .order(published_at: :desc)
    scope = scope.joins(:category).where(railspress_categories: { slug: params[:category] }) if params[:category].present?
    scope = scope.joins(:tags).where(railspress_tags: { slug: params[:tag] }) if params[:tag].present?
    @pagy, @posts = pagy(scope, limit: PER_PAGE)
  end

  def show
    @post = Railspress::Post.published.find_by!(slug: params[:id])
    set_meta_tags(
      title: @post.meta_title.presence || @post.title,
      description: @post.meta_description.presence || plain_text_description
    )
  end

  private

  def plain_text_description
    Rails.cache.fetch([ @post, :description ]) { @post.content.to_plain_text.truncate(160) }
  end
end
