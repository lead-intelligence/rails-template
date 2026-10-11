require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "requires authentication" do
    get documents_url
    assert_redirected_to new_session_url
  end

  test "creates a document with rich content" do
    sign_in_as users(:one)
    assert_difference("Document.count") do
      post documents_url, params: { document: { title: "Kamal notes", content: "<p>Deploy with <strong>Kamal</strong></p>" } }
    end
    document = Document.last
    assert_equal users(:one), document.user
    assert_includes document.content.to_plain_text, "Deploy with Kamal"
  end

  test "does not show another user's document" do
    sign_in_as users(:one)
    other = users(:two).documents.create!(title: "Private", content: "secret")
    get document_url(other)
    assert_response :not_found
  end

  test "lists own documents" do
    sign_in_as users(:one)
    users(:one).documents.create!(title: "Kamal notes", content: "Deploy with Kamal")
    get documents_url
    assert_response :success
    assert_not_embedding_loaded
  end

  test "lists one page of own documents and links to the next" do
    sign_in_as users(:one)
    (DocumentsController::PER_PAGE + 1).times { |index| users(:one).documents.create!(title: "Document #{index}") }

    get documents_url

    assert_select "li.list-row", count: DocumentsController::PER_PAGE
    assert_select "nav.pagy a[rel=next][href=?]", documents_path(page: 2)
    assert_not_embedding_loaded
  end

  test "lists the remaining own documents on the second page" do
    sign_in_as users(:one)
    (DocumentsController::PER_PAGE + 1).times { |index| users(:one).documents.create!(title: "Document #{index}") }

    get documents_url(page: 2)

    assert_select "li.list-row", count: users(:one).documents.count - DocumentsController::PER_PAGE
  end

  test "shows the empty state when there are no documents" do
    sign_in_as users(:one)
    users(:one).documents.destroy_all

    get documents_url

    assert_select "p", text: I18n.t("documents.index.empty")
    assert_select "nav.pagy", count: 0
  end

  test "paginates the plain list it falls back to when the search provider fails" do
    sign_in_as users(:one)
    (DocumentsController::PER_PAGE + 1).times { |index| users(:one).documents.create!(title: "Document #{index}") }
    stub_request(:post, "https://api.openai.com/v1/embeddings").to_return(
      status: 503, headers: { "Content-Type" => "application/json" }, body: { error: { message: "Service unavailable" } }.to_json
    )

    assert_error_reported(RubyLLM::Error) do
      get documents_url, params: { q: "How do I deploy?" }
    end

    assert_select "li.list-row", count: DocumentsController::PER_PAGE
    assert_select "nav.pagy a[rel=next]"
  end

  test "searches own documents semantically" do
    sign_in_as users(:one)
    document = users(:one).documents.create!(title: "Kamal notes", content: "Deploy with Kamal")
    vector = Array.new(Document::EMBEDDING_DIMENSIONS, 0.0).tap { |v| v[0] = 1.0 }
    document.update!(embedding: vector)
    stub_openai_embedding(vector: vector)

    get documents_url, params: { q: "How do I deploy?" }

    assert_response :success
    assert_includes @response.body, "Kamal notes"
    assert_not_embedding_loaded
  end

  test "records the search embedding's usage against the person searching" do
    sign_in_as users(:one)
    stub_openai_embedding(vector: Array.new(Document::EMBEDDING_DIMENSIONS, 0.5))

    get documents_url, params: { q: "How do I deploy?" }

    assert_equal [ "embedding" ], users(:one).ruby_llm_usages.pluck(:operation)
  end

  test "falls back to the plain list when the search provider fails" do
    sign_in_as users(:one)
    users(:one).documents.create!(title: "Kamal notes", content: "Deploy with Kamal")
    stub_request(:post, "https://api.openai.com/v1/embeddings").to_return(
      status: 503, headers: { "Content-Type" => "application/json" }, body: { error: { message: "Service unavailable" } }.to_json
    )

    assert_error_reported(RubyLLM::Error) do
      get documents_url, params: { q: "How do I deploy?" }
    end

    assert_response :success
    assert_equal I18n.t("documents.index.search_unavailable"), flash[:alert]
    assert_includes @response.body, "Kamal notes"
  end

  test "shows own document" do
    sign_in_as users(:one)
    document = users(:one).documents.create!(title: "Kamal notes", content: "Deploy with Kamal")
    get document_url(document)
    assert_response :success
  end

  test "shows a new document form" do
    sign_in_as users(:one)
    get new_document_url
    assert_response :success
  end

  test "does not create a document with a blank title" do
    sign_in_as users(:one)
    assert_no_difference("Document.count") do
      post documents_url, params: { document: { title: "", content: "Deploy with Kamal" } }
    end
    assert_response :unprocessable_entity
  end

  test "shows the edit form for an own document" do
    sign_in_as users(:one)
    document = users(:one).documents.create!(title: "Kamal notes", content: "Deploy with Kamal")
    get edit_document_url(document)
    assert_response :success
  end

  test "updates an own document" do
    sign_in_as users(:one)
    document = users(:one).documents.create!(title: "Kamal notes", content: "Deploy with Kamal")
    patch document_url(document), params: { document: { title: "Kamal deploys", content: "Updated" } }
    assert_redirected_to document
    assert_equal "Kamal deploys", document.reload.title
  end

  test "does not update a document with a blank title" do
    sign_in_as users(:one)
    document = users(:one).documents.create!(title: "Kamal notes", content: "Deploy with Kamal")
    patch document_url(document), params: { document: { title: "" } }
    assert_response :unprocessable_entity
    assert_equal "Kamal notes", document.reload.title
  end

  test "destroys an own document" do
    sign_in_as users(:one)
    document = users(:one).documents.create!(title: "Kamal notes", content: "Deploy with Kamal")
    assert_difference("Document.count", -1) do
      delete document_url(document)
    end
    assert_redirected_to documents_url
  end

  private

  def assert_not_embedding_loaded
    documents = controller.instance_variable_get(:@documents).to_a
    assert_not_empty documents
    documents.each { |document| assert_not document.has_attribute?(:embedding) }
  end
end
