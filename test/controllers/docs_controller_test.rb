require "test_helper"

class DocsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_user = ENV["SUPERADMIN_USER"]
    @original_password = ENV["SUPERADMIN_PASSWORD"]
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"
  end

  teardown do
    ENV["SUPERADMIN_USER"] = @original_user
    ENV["SUPERADMIN_PASSWORD"] = @original_password
  end

  def superadmin_headers
    { "Authorization" => "Basic #{Base64.strict_encode64("superadmin:secret")}" }
  end

  test "requires basic auth credentials" do
    get docs_url

    assert_response :unauthorized
  end

  test "refuses the wrong credentials" do
    get docs_url, headers: { "Authorization" => "Basic #{Base64.strict_encode64("superadmin:wrong")}" }

    assert_response :unauthorized
  end

  test "refuses credentials without a colon" do
    get docs_url, headers: { "Authorization" => "Basic #{Base64.strict_encode64("superadmin")}" }

    assert_response :unauthorized
  end

  test "denies access when no credentials are configured" do
    ENV["SUPERADMIN_USER"] = nil
    ENV["SUPERADMIN_PASSWORD"] = nil

    get docs_url, headers: superadmin_headers

    assert_response :unauthorized
  end

  test "the index lists a card for every page" do
    get docs_url, headers: superadmin_headers

    assert_response :success
    assert_select "a[href=?]", doc_path("README")
    assert_select "a[href=?]", doc_path("CLAUDE")
    assert_select "a[href=?]", doc_path("architecture/superadmin-panels")
    assert_select "h2", text: I18n.t("docs.sections.architecture")
  end

  test "the index embeds the search index" do
    get docs_url, headers: superadmin_headers

    index = JSON.parse(css_select("script[type='application/json']").first.text)

    assert_includes index.map { |entry| entry["title"] }, "Superadmin panels"
    assert_includes index.map { |entry| entry["path"] }, doc_path("architecture/superadmin-panels")
  end

  test "the search index carries each page's plain body text" do
    get docs_url, headers: superadmin_headers

    index = JSON.parse(css_select("script[type='application/json']").first.text)
    entry = index.find { |candidate| candidate["path"] == doc_path("architecture/superadmin-panels") }

    assert_includes entry["body"], "secure_compare"
    assert_not_includes entry["body"], "`"
  end

  test "a page renders its markdown, its sidebar and its table of contents" do
    get doc_url("CLAUDE"), headers: superadmin_headers

    assert_response :success
    assert_select "article.docs h1"
    assert_select "nav a[href=?]", doc_path("architecture/auth")
    assert_select "a[href='#conventions']"
  end

  test "a page without subheadings has no table of contents" do
    get doc_url("architecture/superadmin-panels"), headers: superadmin_headers

    assert_response :success
    assert_select "article.docs h1", text: "Superadmin panels"
    assert_select "nav[aria-label=?]", I18n.t("docs.show.on_this_page"), count: 0
  end

  test "a backticked page reference inside the markdown becomes a link between pages" do
    get doc_url("CLAUDE"), headers: superadmin_headers

    assert_select "article.docs a[href=?]", doc_path("architecture/auth")
    assert_select "article.docs code", text: "bin/dev"
  end

  test "an unknown page is a 404" do
    get doc_url("architecture/nope"), headers: superadmin_headers

    assert_response :not_found
  end

  test "a slug that walks out of the documentation tree is a 404" do
    get "/docs/architecture/..%2F..%2Fconfig%2Fmaster", headers: superadmin_headers

    assert_response :not_found
  end
end
