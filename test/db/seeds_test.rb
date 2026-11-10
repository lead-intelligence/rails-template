require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  setup do
    RubyLLM::ActiveRecord::Model.delete_all
    RubyLLM::ActiveRecord::Model.create!(model_id: "gpt-4o-mini", provider: "openai", name: "GPT-4o mini")
    RubyLLM.models.load_from_store
  end

  teardown do
    RubyLLM.models.load_from_json
  end

  test "a registry read from a table holding only the chat model cannot embed" do
    assert_raises(RubyLLM::ModelNotFoundError) { Document.semantic_search("deploy") }
  end

  test "seeding loads the bundled registry into the table once, and resolves the embedding model" do
    Rails.application.load_seed

    assert RubyLLM::ActiveRecord::Model.exists?(model_id: "text-embedding-3-small", provider: "openai")
    assert_no_difference("RubyLLM::ActiveRecord::Model.count") { Rails.application.load_seed }
    RubyLLM.models.load_from_store

    vector = Array.new(Document::EMBEDDING_DIMENSIONS, 0.0).tap { |v| v[0] = 1.0 }
    document = users(:one).documents.create!(title: "Kamal", content: "Deploy fast")
    document.update!(embedding: vector)
    stub_openai_embedding(vector: vector)

    assert_equal [ document ], Document.semantic_search("deploy")
  end

  test "the seeds of every feature load twice for an owner, and create nothing the second time" do
    ENV["SEED_OWNER"] = users(:one).email_address
    Rails.application.load_seed

    counts = ActiveRecord::Base.descendants.reject(&:abstract_class?).select(&:table_exists?).to_h { [ it.name, it.count ] }
    Rails.application.load_seed

    assert_equal counts, ActiveRecord::Base.descendants.reject(&:abstract_class?).select(&:table_exists?).to_h { [ it.name, it.count ] }
  ensure
    ENV.delete("SEED_OWNER")
  end
end
