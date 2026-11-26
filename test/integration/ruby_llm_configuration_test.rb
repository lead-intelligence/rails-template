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

    assert_equal "gpt-5.4-nano", RubyLLM.config.default_model
    assert_equal "text-embedding-3-small", RubyLLM.config.default_embedding_model
  end

  test "gives up on a stalled provider before it holds a job thread for minutes" do
    assert_equal 60, RubyLLM.config.request_timeout
    assert_equal 30, RubyLLM.config.stream_idle_timeout
  end

  test "allows only cheap chat models by default, the default among them" do
    assert_equal %w[gpt-5.4-nano gpt-5.4-mini gpt-5-mini], Rails.configuration.x.selectable_chat_models
    assert_includes Rails.configuration.x.selectable_chat_models, RubyLLM.config.default_model
  end
end
