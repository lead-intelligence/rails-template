require "test_helper"

class RubyLlmConfigurationTest < ActiveSupport::TestCase
  test "reads the chat and embedding model names from ENV" do
    ENV["OPENAI_CHAT_MODEL"] = "gpt-4.1-mini"
    ENV["OPENAI_EMBEDDING_MODEL"] = "text-embedding-3-large"

    load Rails.root.join("config/initializers/ruby_llm.rb")

    assert_equal "gpt-4.1-mini", RubyLLM.config.default_model
    assert_equal "text-embedding-3-large", RubyLLM.config.default_embedding_model
  ensure
    ENV.delete("OPENAI_CHAT_MODEL")
    ENV.delete("OPENAI_EMBEDDING_MODEL")
    load Rails.root.join("config/initializers/ruby_llm.rb")
  end

  test "falls back to the default model names when ENV is unset" do
    ENV.delete("OPENAI_CHAT_MODEL")
    ENV.delete("OPENAI_EMBEDDING_MODEL")

    load Rails.root.join("config/initializers/ruby_llm.rb")

    assert_equal "gpt-4o-mini", RubyLLM.config.default_model
    assert_equal "text-embedding-3-small", RubyLLM.config.default_embedding_model
  end

  test "allows only cheap chat models by default" do
    assert_equal %w[gpt-4o-mini gpt-4.1-mini gpt-4.1-nano], Rails.configuration.x.selectable_chat_models
  end
end
