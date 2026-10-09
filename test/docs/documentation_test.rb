require "test_helper"

class DocumentationTest < ActiveSupport::TestCase
  MAX_LINE_LENGTH = 300
  MAP_ENTRY = /→ `([^`]+\.md)`/
  BACKTICKED = /`([^`]+)`/
  CITED_PATH = %r{\A(?:app|config|lib|test|bin|db)/[A-Za-z0-9_.*/-]+\z}
  CROSS_REFERENCE = /\b[a-z][a-z-]*\.md\b/
  CROSS_REFERENCE_WHITELIST = %w[README.md CLAUDE.md].freeze

  test "every page the subsystem map points at exists, and every page is in the map" do
    assert_empty mapped_pages - architecture_pages,
      "CLAUDE.md's subsystem map points at pages that are missing from docs/architecture/"
    assert_empty architecture_pages - mapped_pages,
      "pages in docs/architecture/ that no line of CLAUDE.md's subsystem map points at"
  end

  test "every cross-reference between architecture pages names a page that exists" do
    offenders = Dir.glob(ARCHITECTURE.join("*.md")).sort.flat_map do |page|
      path = Pathname.new(page)
      cross_referenced_pages(path).reject { |name| architecture_pages.include?(name) }.map do |name|
        "#{path.relative_path_from(Rails.root)} references #{name}"
      end
    end

    assert_empty offenders, "docs/architecture pages reference other pages that do not exist there"
  end

  test "no line of CLAUDE.md is longer than an index entry should be" do
    offenders = []
    fenced = false

    CLAUDE_MD.readlines.each_with_index do |line, index|
      fence = line.strip.start_with?("```")
      fenced = !fenced if fence
      next if fenced || fence

      length = line.chomp.length
      offenders << "CLAUDE.md:#{index + 1} is #{length} characters" if length > MAX_LINE_LENGTH
    end

    assert_empty offenders, "lines over #{MAX_LINE_LENGTH} characters (the detail belongs in docs/architecture/)"
  end

  test "every file path the documentation cites exists and is tracked" do
    offenders = documented_files.flat_map do |doc|
      cited_paths(doc).reject { |path| exists?(path) }.map do |path|
        "#{doc.relative_path_from(Rails.root)} cites #{path}"
      end
    end

    assert_empty offenders, "documented paths that no longer exist in the tree, or that git does not track (a spawned app is a clone)"
  end

  test "a cited file on disk that git does not track counts as missing, except in an export with no repository" do
    probe = Rails.root.join("db/untracked_documentation_probe.txt")
    probe.write("probe")

    assert_equal !Rails.root.join(".git").exist?, exists?("db/untracked_documentation_probe.txt"),
      "with a repository only tracked files count; a git archive export carries only tracked files, so the disk decides there"
  ensure
    probe&.delete
  end

  private

  CLAUDE_MD = Rails.root.join("CLAUDE.md")
  ARCHITECTURE = Rails.root.join("docs/architecture")

  def mapped_pages
    CLAUDE_MD.read.scan(MAP_ENTRY).flatten.uniq.sort
  end

  def architecture_pages
    Dir.glob(ARCHITECTURE.join("*.md")).map { |page| File.basename(page) }.sort
  end

  def documented_files
    [ CLAUDE_MD ] + Dir.glob(ARCHITECTURE.join("*.md")).sort.map { |page| Pathname.new(page) }
  end

  def cited_paths(doc)
    unfenced(doc.read).scan(BACKTICKED).flatten.flat_map { |span| span.split(/\s+/) }
       .reject { |token| token.include?("<") }
       .select { |token| token.match?(CITED_PATH) }
       .uniq
  end

  def cross_referenced_pages(doc)
    unfenced(doc.read).scan(CROSS_REFERENCE).reject { |name| CROSS_REFERENCE_WHITELIST.include?(name) }.uniq
  end

  def unfenced(content)
    content.gsub(/```.*?```/m, "")
  end

  def exists?(path)
    on_disk?(path) && tracked?(path)
  end

  def on_disk?(path)
    return Dir.glob(Rails.root.join(path)).any? if path.include?("*")

    Rails.root.join(path).exist?
  end

  def tracked?(path)
    return true unless Rails.root.join(".git").exist?

    pattern = path.chomp("/")
    return tracked_paths.include?(pattern) unless pattern.include?("*")

    tracked_paths.any? { |tracked| File.fnmatch?(pattern, tracked, File::FNM_PATHNAME) }
  end

  def tracked_paths
    @tracked_paths ||= IO.popen([ "git", "-C", Rails.root.to_s, "ls-files", "-z" ], &:read)
      .split("\0").flat_map { |file| Pathname.new(file).ascend.map(&:to_s) }.to_set
  end
end
