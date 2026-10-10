# Rich text

Action Text with the Lexxy editor. The pieces are a manual `pin "lexxy"` in `config/importmap.rb` with `preload: false`, the on-demand loader in `app/javascript/load_rich_text_editor.js`, and `stylesheet_link_tag "lexxy"` in the layout — Lexxy is not pinned by `bin/importmap`, so a fresh pin has to be added by hand.

Lexxy is close to a megabyte of JavaScript, and only a page with a `lexxy-editor` element needs it. The loader imports it the first time one is in the document, whether it arrives with the first load, a Turbo navigation, a frame or a stream, so a page with no editor never downloads it. A static `import "lexxy"` in `application.js` puts it back on every page. The RailsPress admin renders its editors through the same `application` entry point, so it depends on this loader too.

On Rails 8.1 Lexxy has no official editor adapter to plug into, so it monkey-patches `rich_text_area` and `rich_textarea` instead. Re-check `Lexxy.supports_editor_adapter?` after any Rails upgrade: the rendered `lexxy-editor` tag should be identical either way, but the path that produces it changes, so re-run the Lexxy system test to confirm.
