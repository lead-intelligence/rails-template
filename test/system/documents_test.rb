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
end
