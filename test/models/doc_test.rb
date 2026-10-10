require "test_helper"

class DocTest < ActiveSupport::TestCase
  test "all lists the guides first and then every architecture page" do
    slugs = Doc.all.map(&:slug)

    assert_equal %w[README CLAUDE], slugs.first(2)
    assert_includes slugs, "architecture/superadmin-panels"
    assert_includes slugs, "architecture/auth"
    assert_equal slugs.drop(2), slugs.drop(2).sort
  end

  test "all stays inside the guides and the architecture directory" do
    paths = Doc.all.map(&:path)

    assert_equal paths, paths.select { |path| path.start_with?("docs/architecture/") || !path.include?("/") }
    assert_empty paths.grep(/superpowers/)
  end

  test "every page belongs to a section" do
    sections = Doc.all.map(&:section).uniq

    assert_equal [ :guide, :architecture ], sections
  end

  test "find returns the page with that slug" do
    doc = Doc.find("architecture/superadmin-panels")

    assert_equal "docs/architecture/superadmin-panels.md", doc.path
  end

  test "find refuses a slug that is not listed" do
    assert_raises(ActiveRecord::RecordNotFound) { Doc.find("architecture/nope") }
  end

  test "find refuses to walk out of the documentation tree" do
    assert_raises(ActiveRecord::RecordNotFound) { Doc.find("../config/master") }
    assert_raises(ActiveRecord::RecordNotFound) { Doc.find("architecture/../../config/credentials") }
  end

  test "title is the first heading and summary the first paragraph" do
    doc = Doc.find("architecture/superadmin-panels")

    assert_equal "Superadmin panels", doc.title
    assert_match(/gated by ONE shared HTTP basic-auth credential pair/, doc.summary)
  end

  test "the guides get distinct titles instead of their shared heading" do
    assert_equal I18n.t("docs.guides.readme"), Doc.find("README").title
    assert_equal I18n.t("docs.guides.agent_guide"), Doc.find("CLAUDE").title
    assert_not_equal Doc.find("README").title, Doc.find("CLAUDE").title
  end

  test "summary is empty when the page is nothing but a heading" do
    assert_equal "", Doc.summary_of("# Only a heading\n")
  end

  test "summary skips lists, quotes and code and collapses the paragraph it finds" do
    content = "# Title\n\n- a list\n\n> a quote\n\n```\ncode\n```\n\nThe\nfirst\nparagraph.\n"

    assert_equal "The first paragraph.", Doc.summary_of(content)
  end

  test "summary strips inline markdown: backticks, links and emphasis" do
    content = "# Title\n\nRun `bin/rename <name>` then read the **guide** or [the docs](docs/architecture/auth.md).\n"

    summary = Doc.summary_of(content)

    assert_not_includes summary, "`"
    assert_not_includes summary, "**"
    assert_not_includes summary, "["
    assert_includes summary, "Run bin/rename <name> then read the guide"
  end

  test "html renders the markdown" do
    html = Doc.find("architecture/superadmin-panels").html

    assert_includes html, %(<h1 id="superadmin-panels">Superadmin panels</h1>)
    assert_includes html, "<code>"
  end

  test "headings carry the anchors the rendered html uses" do
    doc = Doc.find("CLAUDE")

    anchors = doc.headings.map { |heading| heading[:anchor] }

    assert_includes doc.headings.map { |heading| heading[:text] }, "Conventions"
    assert_includes anchors, "#conventions"
    anchors.each { |anchor| assert_includes doc.html, %(id="#{anchor.delete_prefix('#')}") }
  end

  test "a page without subheadings has no table of contents" do
    assert_empty Doc.find("architecture/superadmin-panels").headings
  end

  test "route resolves a page reference to its documentation path" do
    assert_equal "/docs/architecture/auth", Doc.route("auth.md")
    assert_equal "/docs/architecture/auth", Doc.route("docs/architecture/auth.md")
    assert_equal "/docs/README", Doc.route("README.md")
    assert_equal "/docs/architecture/auth#tokens", Doc.route("auth.md#tokens")
  end

  test "route ignores anything that is not a documentation page" do
    assert_nil Doc.route("app/models/user.rb")
    assert_nil Doc.route("https://rubyonrails.org")
    assert_nil Doc.route("#anchor")
  end

  test "links to other pages become documentation links and external links stay" do
    html = Doc.markdown.render("[auth](auth.md) and [rails](https://rubyonrails.org)")

    assert_includes html, %(href="/docs/architecture/auth")
    assert_includes html, %(href="https://rubyonrails.org")
  end

  test "a backticked page reference becomes a link and any other code span does not" do
    html = Doc.markdown.render("See `auth.md` in `app/models/user.rb`")

    assert_includes html, %(<a href="/docs/architecture/auth"><code>auth.md</code></a>)
    assert_includes html, "<code>app/models/user.rb</code>"
    assert_not_includes html, %(href="app/models/user.rb")
  end

  test "every render gets parsers of its own, because Redcarpet aborts the process when threads share one" do
    assert_not_same Doc.markdown, Doc.markdown
    assert_not_same Doc.table_of_contents, Doc.table_of_contents
    assert_not_same Doc.plain_text, Doc.plain_text
  end

  test "raw html in a page is filtered out" do
    html = Doc.markdown.render("<script>alert(1)</script>\n\nplain")

    assert_not_includes html, "<script>"
  end

  test "the search index is built once and follows an edited or an added page" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join(Doc::ARCHITECTURE).mkpath
      Doc::GUIDES.each { |guide| root.join(guide).write("# Guide\n") }
      page = root.join(Doc::ARCHITECTURE, "alpha.md")
      page.write("# Alpha\n\nFirst text.\n")

      with_doc_root(root) do
        first = Doc.search_index

        assert_includes first, "First text."
        assert_same first, Doc.search_index

        page.write("# Alpha\n\nEdited text.\n")
        File.utime(Time.now + 1, Time.now + 1, page)
        root.join(Doc::ARCHITECTURE, "beta.md").write("# Beta\n")
        File.utime(Time.now + 1, Time.now + 1, root.join(Doc::ARCHITECTURE))

        rebuilt = Doc.search_index

        assert_includes rebuilt, "Edited text."
        assert_includes rebuilt, "Beta"
        assert_equal %w[README CLAUDE architecture/alpha architecture/beta], Doc.all.map(&:slug)
      end
    end
  end

  private
    def with_doc_root(root)
      original_root = Doc.method(:root)
      Doc.define_singleton_method(:root) { root }
      yield
    ensure
      Doc.define_singleton_method(:root, original_root)
    end
end
