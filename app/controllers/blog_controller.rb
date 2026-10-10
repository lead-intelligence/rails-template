class BlogController < ApplicationController
  allow_unauthenticated_access

  def index
    scope = Railspress::Post.published
                            .includes(:category, :tags)
                            .with_attached_header_image
                            .order(published_at: :desc)
    scope = scope.where(category: Railspress::Category.find_by(slug: params[:category])) if params[:category].present?
    scope = scope.joins(:tags).where(railspress_tags: { slug: params[:tag] }) if params[:tag].present?
    @posts = scope
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
