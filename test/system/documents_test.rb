require "application_system_test_case"

class DocumentsTest < ApplicationSystemTestCase
  test "new document form renders the Lexxy editor" do
    sign_in_via_browser(users(:one))
    visit new_document_url
    assert_selector "lexxy-editor [contenteditable=true]"
  end

  test "the Lexxy editor loads after a Turbo navigation from a page without one" do
    sign_in_via_browser(users(:one))
    visit documents_url
    assert_no_selector "lexxy-editor"

    click_on t("documents.index.new_document")

    assert_selector "lexxy-editor [contenteditable=true]"
  end

  test "pages through the documents" do
    sign_in_via_browser(users(:one))
    stub_openai_embedding(vector: Array.new(Document::EMBEDDING_DIMENSIONS, 0.0))
    DocumentsController::PER_PAGE.times { |index| users(:one).documents.create!(title: "Document #{index}") }

    visit documents_url
    assert_selector "li.list-row", count: DocumentsController::PER_PAGE

    find("nav.pagy a[aria-label='#{t("pagy.aria_label.next")}']").click

    assert_current_path documents_path(page: 2)
    assert_selector "li.list-row", count: users(:one).documents.count - DocumentsController::PER_PAGE
  end
end
