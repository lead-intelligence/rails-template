require "application_system_test_case"

class DocsTest < ApplicationSystemTestCase
  setup do
    @original_user = ENV["SUPERADMIN_USER"]
    @original_password = ENV["SUPERADMIN_PASSWORD"]
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"
    page.driver.basic_authorize("superadmin", "secret")
  end

  teardown do
    ENV["SUPERADMIN_USER"] = @original_user
    ENV["SUPERADMIN_PASSWORD"] = @original_password
  end

  test "the landing lists every page, remembers the theme and opens a card" do
    visit docs_url

    assert_selector "h1", text: t("docs.index.hero_title")
    assert_link "Superadmin panels"

    find("input.theme-controller[value='dark']").click

    assert_selector "input.theme-controller[value='dark']:checked"
    assert_equal "dark", page.evaluate_script("window.localStorage.getItem('docs-theme')")

    click_link "Superadmin panels"

    assert_selector "article.docs h1", text: "Superadmin panels"
  end

  test "the search filters the pages and the keyboard navigates to one" do
    visit docs_url

    click_button t("layouts.docs.search")
    fill_in "docs-search-input", with: "zzzzzzzz"

    assert_text t("layouts.docs.no_results")

    fill_in "docs-search-input", with: "superadmin panels"

    assert_selector "dialog[open] a", text: "Superadmin panels"

    find("#docs-search-input").send_keys(:enter)

    assert_selector "article.docs h1", text: "Superadmin panels"
  end

  test "the search also matches a page's body text and navigates to it" do
    visit docs_url

    click_button t("layouts.docs.search")
    fill_in "docs-search-input", with: "tombstoned"

    assert_selector "dialog[open] a", text: "AI chat"

    find("#docs-search-input").send_keys(:enter)

    assert_selector "article.docs h1", text: "AI chat"
  end

  test "a page shows its sidebar, its table of contents and links to the pages it names" do
    visit doc_url("CLAUDE")

    assert_selector "article.docs h1"
    assert_selector "nav a[href='#conventions']"
    assert_selector "nav a[href='#{doc_path('architecture/auth')}']"

    find("article.docs a[href='#{doc_path('architecture/blog')}']", match: :first).click

    assert_selector "article.docs h1", text: "Blog and content"
  end

  test "on a narrow screen the menu button is accessible and opens the sidebar" do
    page.current_window.resize_to(390, 844)

    visit doc_url("CLAUDE")

    find("label[for=docs-drawer]", text: t("layouts.docs.open_menu")).click

    assert_selector "#docs-drawer:checked", visible: :all
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
