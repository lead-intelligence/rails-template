require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  setup do
    Model.create!(model_id: "gpt-4o-mini", provider: "openai", name: "GPT-4o mini")
    RubyLLM.models.load_from_database!
  end

  teardown do
    RubyLLM.models.load_from_json!
  end

  test "a registry read from a table holding only the chat model cannot embed" do
    assert_raises(RubyLLM::ModelNotFoundError) { Document.semantic_search("deploy") }
  end

  test "seeding loads the bundled registry into the table once, and resolves the embedding model" do
    Rails.application.load_seed

    assert Model.exists?(model_id: "text-embedding-3-small", provider: "openai")
    assert_no_difference("Model.count") { Rails.application.load_seed }

    vector = Array.new(Document::EMBEDDING_DIMENSIONS, 0.0).tap { |v| v[0] = 1.0 }
    document = users(:one).documents.create!(title: "Kamal", content: "Deploy fast")
    document.update!(embedding: vector)
    stub_openai_embedding(vector: vector)

    assert_equal [ document ], Document.semantic_search("deploy")
  end
end
