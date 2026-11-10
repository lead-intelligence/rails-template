class GenerateDocumentEmbeddingJob < ApplicationJob
  queue_as :default
  retry_on RubyLLM::RateLimitError, RubyLLM::ServerError, RubyLLM::ServiceUnavailableError, wait: :polynomially_longer, attempts: 5

  def perform(document)
    document.update!(embedding: RubyLLM.embed(document.embedding_source_text, owner: document.user).vectors)
  end
end
