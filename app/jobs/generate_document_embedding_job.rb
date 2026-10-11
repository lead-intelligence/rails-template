class GenerateDocumentEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(document)
    document.update!(embedding: RubyLLM.embed(document.embedding_source_text, owner: document.user).vectors)
  end
end
