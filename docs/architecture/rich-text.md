# Rich text

Action Text with the Lexxy editor. The pieces are a manual `pin "lexxy"` in `config/importmap.rb` with `preload: false`, the on-demand loader in `app/javascript/load_rich_text_editor.js`, and `stylesheet_link_tag "lexxy"` in the layout — Lexxy is not pinned by `bin/importmap`, so a fresh pin has to be added by hand.

Lexxy is close to a megabyte of JavaScript, and only a page with a `lexxy-editor` element needs it. The loader imports it the first time one is in the document, whether it arrives with the first load, a Turbo navigation, a frame or a stream, so a page with no editor never downloads it. A static `import "lexxy"` in `application.js` puts it back on every page. The RailsPress admin renders its editors through the same `application` entry point, so it depends on this loader too.

On Rails 8.1 Lexxy has no official editor adapter to plug into, so it monkey-patches `rich_text_area` and `rich_textarea` instead. Re-check `Lexxy.supports_editor_adapter?` after any Rails upgrade: the rendered `lexxy-editor` tag should be identical either way, but the path that produces it changes, so re-run the Lexxy system test to confirm.

Lexxy and the RailsPress admin upload through `/rails/active_storage/direct_uploads`, which the app routes to `DirectUploadsController` before Active Storage draws its own. The Active Storage controller has no authentication, so anyone could fill the `storage/` volume that also holds the databases. Ours accepts a signed-in person or the superadmin, because the RailsPress admin has basic auth and no session. It refuses a file over `DirectUpload::MAX_BYTE_SIZE` with `413` and rate-limits per client. The `PUT` to the disk service needs the signed URL that only this action returns, so it needs no gate of its own.

A direct upload makes its blob before any record attaches it, and an abandoned form leaves it behind. `DirectUpload.purge_abandoned` runs every day from `config/recurring.yml` and purges every unattached blob older than `DirectUpload::ABANDONED_AFTER`.
