RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.default_model = ENV.fetch("OPENAI_CHAT_MODEL", "gpt-5.4-nano")
  config.default_embedding_model = ENV.fetch("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
  config.openai_protocol = :chat_completions
  config.request_timeout = 60
  config.stream_idle_timeout = 30
end

Rails.application.config.x.selectable_chat_models = %w[gpt-5.4-nano gpt-5.4-mini gpt-5-mini]
