RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.default_model = ENV.fetch("OPENAI_CHAT_MODEL", "gpt-4o-mini")
  config.default_embedding_model = ENV.fetch("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
  config.openai_protocol = :chat_completions
end
