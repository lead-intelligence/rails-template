module DocsHelper
  DOC_TAGS = %w[h1 h2 h3 h4 h5 h6 p a ul ol li blockquote pre code em strong del hr br table thead tbody tr th td].freeze
  DOC_ATTRIBUTES = %w[href id lang].freeze

  def doc_body(doc)
    sanitize doc.html, tags: DOC_TAGS, attributes: DOC_ATTRIBUTES
  end

  def doc_section_title(section)
    section == :guide ? t("docs.sections.guide") : t("docs.sections.architecture")
  end

  def doc_icon(doc)
    doc.section == :guide ? "book-open" : "layers"
  end
end
