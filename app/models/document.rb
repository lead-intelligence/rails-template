class Document < ApplicationRecord
  TITLE_MAX_LENGTH = 200

  belongs_to :user
  has_rich_text :content

  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }

  EMBEDDING_DIMENSIONS = 1536
  EMBEDDING_SOURCE_BYTES = 8_191

  has_neighbors :embedding, dimensions: EMBEDDING_DIMENSIONS
  after_save_commit :refresh_embedding_later, if: :embedding_source_changed?

  def self.semantic_search(query, limit: 5)
    query_embedding = RubyLLM.embed(query).vectors
    where.not(embedding: nil).nearest_neighbors(:embedding, query_embedding, distance: "cosine").first(limit)
  end

  def embedding_source_text
    [ title, content.to_plain_text ].join("\n").strip.truncate_bytes(EMBEDDING_SOURCE_BYTES, omission: "")
  end

  private

  def embedding_source_changed?
    saved_change_to_title? || content.saved_change_to_body?
  end

  def refresh_embedding_later
    GenerateDocumentEmbeddingJob.perform_later(self)
  end
end
