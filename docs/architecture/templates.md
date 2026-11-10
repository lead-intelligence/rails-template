# Templates

ReActionView puts `Herb::Engine` in front of every `.html.erb` template in every environment: `config/initializers/reactionview.rb` sets `config.intercept_erb = true`, so a mismatched or unclosed HTML tag is a compile-time error instead of a silently broken render.

Validation follows the environment. Test keeps the gem default, a hard raise, so a malformed template fails `bin/rails test` for a clear reason. Development keeps the gem default too, the in-browser overlay with the debug attributes and the dev tools. Production sets `validation_mode` to `:none`: with the overlay on, ReActionView mounts `Herb::Engine::Runtime::Middleware`, which wraps every request and, when a template has a finding, writes a report with template paths into the page a visitor receives. CI already rejects those templates, so production has nothing to show. `test/integration/template_engine_test.rb` boots each environment and asserts the mode and the middleware.

The gem pins its client, `reactionview.esm.js`, as a preloaded module, and its installer imports it from the JavaScript entry point. That client is the runtime of reactive templates only — the overlay and the dev tools load their own script — so with reactive templates off nothing uses it. `app/javascript/application.js` does not import it and `config/importmap.rb` pins it again with `preload: false`, which takes about 113 KB raw and 33 KB gzipped off every page. Turning reactive templates on means importing it again.

`config.slots` stays at its default, `false`: ReActionView's reactive templates are still marked experimental upstream (their markup, payload and JS API can change between releases), so this app only takes the HTML-aware rendering engine, never that feature.

`bin/dev` runs `herb dev` from `Procfile.dev`. The dev tools read its port from a meta tag and open `ws://localhost:<port>`, so the development policy allows that origin in `connect-src`. When a template changes on disk, the page reloads. With `config.slots` off, ReActionView never starts the embedded dev server, so this process is the only one.

`herb dev` misses a save that replaces the file through a rename, such as `sed -i` or an editor set to write a new file. A normal in-place save works.

Herb ships a linter (`herb lint`) and a formatter (`herb format`), but both only delegate to npm packages (`@herb-tools/linter`, `@herb-tools/formatter`) — they refuse to run without a `node` binary on `PATH`. This stack has no Node, so neither is part of `bin/ci`.

`herb analyze`, unlike those two, runs entirely through the gem's native extension: it parses and compiles every template with the same engine ReActionView renders through, and exits non-zero on a parse or validation error. `bin/herb` (the Bundler-generated binstub) runs it in `bin/ci`'s "Templates: Herb analyze" step (`config/ci.rb`), so a malformed template fails the gate before any test boots the app.
