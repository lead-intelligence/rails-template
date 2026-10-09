require "redcarpet/render_strip"

class Doc
  GUIDES = %w[README.md CLAUDE.md].freeze
  GUIDE_LABEL_KEYS = { "README.md" => "readme", "CLAUDE.md" => "agent_guide" }.freeze
  ARCHITECTURE = "docs/architecture".freeze
  SUMMARY_LENGTH = 220
  NOT_A_PARAGRAPH = /\A(?:[#>|`\-*+]|\d+\.)/

  class Renderer < Redcarpet::Render::HTML
    def link(url, _title, content)
      %(<a href="#{escape(Doc.route(url) || url)}">#{content}</a>)
    end

    def codespan(code)
      route = Doc.route(code)
      span = "<code>#{escape(code)}</code>"

      route ? %(<a href="#{escape(route)}">#{span}</a>) : span
    end

    private
      def escape(text)
        ERB::Util.html_escape(text)
      end
  end

  MARKDOWN = Redcarpet::Markdown.new(
    Renderer.new(filter_html: true, with_toc_data: true),
    fenced_code_blocks: true, tables: true, autolink: true, no_intra_emphasis: true, strikethrough: true
  )

  TABLE_OF_CONTENTS = Redcarpet::Markdown.new(Redcarpet::Render::HTML_TOC.new(nesting_level: 2..2))

  PLAIN_TEXT = Redcarpet::Markdown.new(
    Redcarpet::Render::StripDown,
    fenced_code_blocks: true, tables: true, autolink: true, no_intra_emphasis: true, strikethrough: true
  )

  attr_reader :path

  def initialize(path)
    @path = path
  end

  class << self
    def root
      Rails.root
    end

    def all
      paths.map { |page| new(page) }
    end

    def search_index
      docs = all
      key = [ root, I18n.locale, docs.map(&:stamp) ]
      @search_index = [ key, docs.flat_map(&:search_entries).to_json ] unless @search_index&.first == key
      @search_index.last
    end

    def find(slug)
      all.find { |doc| doc.slug == slug } || raise(ActiveRecord::RecordNotFound)
    end

    def route(reference)
      page, anchor = reference.to_s.split("#", 2)
      path = paths.find { |candidate| candidate == page || candidate == "#{ARCHITECTURE}/#{page}" }

      path && [ url_helpers.doc_path(slug_of(path)), anchor ].compact.join("#")
    end

    def summary_of(content)
      paragraph = content.split(/\n{2,}/).map(&:strip).grep_v(NOT_A_PARAGRAPH).first
      strip_markdown(paragraph).truncate(SUMMARY_LENGTH)
    end

    def strip_markdown(markdown)
      PLAIN_TEXT.render(markdown.to_s).squish
    end

    def slug_of(path)
      path.delete_prefix("docs/").delete_suffix(".md")
    end

    def url_helpers
      Rails.application.routes.url_helpers
    end

    private
      def paths
        key = [ root, File.mtime(root.join(ARCHITECTURE)) ]
        @paths = [ key, GUIDES + architecture_pages ] unless @paths&.first == key
        @paths.last
      end

      def architecture_pages
        Dir.glob(root.join(ARCHITECTURE, "*.md")).sort.map { |page| "#{ARCHITECTURE}/#{File.basename(page)}" }
      end
  end

  def slug
    self.class.slug_of(path)
  end

  def section
    GUIDES.include?(path) ? :guide : :architecture
  end

  def title
    guide_label_key = GUIDE_LABEL_KEYS[path]
    return I18n.t("docs.guides.#{guide_label_key}") if guide_label_key

    content[/^#\s+(.+)$/, 1].to_s.strip.presence || slug
  end

  def summary
    self.class.summary_of(content)
  end

  def html
    @html ||= MARKDOWN.render(content)
  end

  def body_text
    @body_text ||= self.class.strip_markdown(content)
  end

  def headings
    @headings ||= Nokogiri::HTML5.fragment(TABLE_OF_CONTENTS.render(content)).css("a").map do |link|
      { text: link.text.strip, anchor: link["href"] }
    end
  end

  def stamp
    [ path, File.mtime(self.class.root.join(path)) ]
  end

  def search_entries
    page = self.class.url_helpers.doc_path(slug)

    [ { title: title, heading: nil, summary: summary, body: body_text, path: page } ] +
      headings.map { |heading| { title: title, heading: heading[:text], summary: "", body: "", path: "#{page}#{heading[:anchor]}" } }
  end

  private
    def content
      @content ||= self.class.root.join(path).read
    end
end
