# Templates

ReActionView puts `Herb::Engine` in front of every `.html.erb` template: `config/initializers/reactionview.rb` sets `config.intercept_erb = true`, so a mismatched or unclosed HTML tag is a compile-time error instead of a silently broken render. `debug_mode` and `validation_mode` keep their gem defaults — an overlay outside test, a hard raise inside it — so a malformed template still fails `bin/rails test` the same way it always would have, just for a clearer reason.

`config.slots` stays at its default, `false`: ReActionView's reactive templates are still marked experimental upstream (their markup, payload and JS API can change between releases), so this app only takes the HTML-aware rendering engine, never that feature.

Herb ships a linter (`herb lint`) and a formatter (`herb format`), but both only delegate to npm packages (`@herb-tools/linter`, `@herb-tools/formatter`) — they refuse to run without a `node` binary on `PATH`. This stack has no Node, so neither is part of `bin/ci`.

`herb analyze`, unlike those two, runs entirely through the gem's native extension: it parses and compiles every template with the same engine ReActionView renders through, and exits non-zero on a parse or validation error. `bin/herb` (the Bundler-generated binstub) runs it in `bin/ci`'s "Templates: Herb analyze" step (`config/ci.rb`), so a malformed template fails the gate before any test boots the app.
