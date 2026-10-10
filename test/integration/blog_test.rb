require "test_helper"

class BlogTest < ActionDispatch::IntegrationTest
  test "index lists published posts with their associations and hides drafts" do
    news = Railspress::Category.create!(name: "News")
    ruby = Railspress::Tag.create!(name: "ruby")
    Railspress::Post.create!(title: "First Post", status: :published, published_at: 2.days.ago, category: news, tags: [ ruby ])
    Railspress::Post.create!(title: "Second Post", status: :published, published_at: 1.day.ago, category: news, tags: [ ruby ])
    Railspress::Post.create!(title: "Secret Draft", status: :draft)

    get blog_url

    assert_response :success
    assert_select "h2", text: /First Post/
    assert_select "h2", text: /Second Post/
    assert_no_match(/Secret Draft/, response.body)
  end

  test "index shows an empty state when there are no posts" do
    get blog_url

    assert_response :success
    assert_select "p", text: I18n.t("blog.index.empty")
  end

  test "index filters by category" do
    news = Railspress::Category.create!(name: "News")
    Railspress::Post.create!(title: "In News", status: :published, published_at: 1.day.ago, category: news)
    Railspress::Post.create!(title: "Uncategorized", status: :published, published_at: 1.day.ago)

    get blog_url(category: news.slug)

    assert_response :success
    assert_select "h2", text: /In News/
    assert_no_match(/Uncategorized/, response.body)
  end

  test "index filters by tag" do
    ruby = Railspress::Tag.create!(name: "ruby")
    Railspress::Post.create!(title: "About Ruby", status: :published, published_at: 1.day.ago, tags: [ ruby ])
    Railspress::Post.create!(title: "About Go", status: :published, published_at: 1.day.ago)

    get blog_url(tag: ruby.slug)

    assert_response :success
    assert_select "h2", text: /About Ruby/
    assert_no_match(/About Go/, response.body)
  end

  test "show renders a published post and uses its SEO fields" do
    post = Railspress::Post.create!(
      title: "My Post", status: :published, published_at: 1.day.ago,
      content: "Body content",
      meta_title: "Custom SEO title", meta_description: "Custom SEO description"
    )

    get blog_post_url(post.slug)

    assert_response :success
    assert_select "h1", text: /My Post/
    assert_includes response.body, "Body content"
    assert_select "title", text: /Custom SEO title/
  end

  test "show falls back to the title and excerpt for SEO when meta fields are blank" do
    post = Railspress::Post.create!(title: "Plain Post", status: :published, published_at: 1.day.ago, content: "Some body")

    get blog_post_url(post.slug)

    assert_response :success
    assert_select "title", text: /Plain Post/
  end

  test "show returns 404 for a draft" do
    draft = Railspress::Post.create!(title: "Draft Post", status: :draft)

    get blog_post_url(draft.slug)

    assert_response :not_found
  end

  test "show returns 404 for an unknown slug" do
    get blog_post_url("does-not-exist")

    assert_response :not_found
  end

  test "show serves a repeat visit without loading the rich text or its embeds" do
    post = published_post_with_embed("Cached body")
    get blog_post_url(post.slug)

    content_queries = []
    collect = ->(*, payload) { content_queries << payload[:sql] if payload[:sql].match?(/action_text_rich_texts|active_storage_blobs/) }
    ActiveSupport::Notifications.subscribed(collect, "sql.active_record") { get blog_post_url(post.slug) }

    assert_response :success
    assert_includes response.body, "Cached body"
    assert_select "figure.attachment img"
    assert_empty content_queries
  end

  test "show renders the new content after the post is edited" do
    post = published_post_with_embed("Old body")
    get blog_post_url(post.slug)

    post.update!(content: "New body")
    get blog_post_url(post.slug)

    assert_includes response.body, "New body"
    assert_no_match(/Old body/, response.body)
    assert_select "meta[name=description][content=?]", "New body"
  end

  private

  def published_post_with_embed(text)
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png")
    content = "<p>#{text}</p>#{ActionText::Attachment.from_attachable(blob).to_html}"
    Railspress::Post.create!(title: "Embedded", status: :published, published_at: 1.day.ago, content: content)
  end
end
