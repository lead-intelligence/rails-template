# CharcoTemplate

Rails starter template. This repo is both a working app and the template new apps are born from (`bin/rename <new_app_name>` after cloning).

## Stack
- Ruby 4.0.6, Rails 8.1.3.1, SQLite everywhere (Solid Queue/Cache/Cable on SQLite)
- Propshaft + Importmap (no Node), Tailwind v4 + DaisyUI 5 (vendored `app/assets/tailwind/daisyui.mjs`, `app/assets/tailwind/daisyui-theme.mjs`)
- Hotwire (Turbo + Stimulus), Lexxy for Action Text rich text
- ReActionView + `Herb::Engine` render every `.html.erb` (HTML-aware, fails on malformed markup); the experimental reactive templates (`slots`) are not adopted
- Lucide icons via `lucide-rails` (`lucide_icon` helper, inline SVG, no icon font/CDN)
- RubyLLM (OpenAI only: `OPENAI_CHAT_MODEL`/`OPENAI_EMBEDDING_MODEL` ENV), Schematist for structured output, Neighbor + sqlite-vec for vector search
- Native Rails authentication (+ registration, profile, email confirmation, active sessions), Active Storage avatars
- console1984 for audited production console access (depends on Active Record encryption)
- money-rails for currency handling (default currency in `config/initializers/money.rb`, no monetized model ships — apps opt in per-model)
- letter_opener_web for development-only email preview at `/letter_opener` (development Gemfile group only)
- noticed for in-app notifications (bell UI + `/notifications`); zero notifiers ship — capability only
- pundit and ahoy_matey, also capability only: zero policies, zero tracked events
- Developer panels behind one shared basic auth: madmin `/madmin`, Mission Control `/jobs`, Solid Errors `/errors`, onlylogs `/onlylogs`
- `railspress-engine` blog/CMS engine at `/railspress` (admin at `/railspress/admin`); the reader-facing `/blog` is this app's own `BlogController`
- Bilingual UI via Rails i18n + `rails-i18n`: Spanish default, English fallback, locale from the browser's `Accept-Language` (no switcher)
- `charco_mobile` (private GitHub gem) for native iOS and Android apps driven from the views: `config/charco_mobile.yml`, `native_*` helpers, `bundle exec charco_mobile check` in `bin/ci`; `action_push_native` stores the apps' push tokens on `User#push_devices`
- Minitest + fixtures + WebMock (tests NEVER hit the network), Capybara + cuprite for system tests, axe-core for accessibility, bullet for N+1, Kamal deploys

## Commands
- `bin/setup` — install and prepare everything. `db:prepare` seeds only on first creation (`db/seeds.rb`): RubyLLM's model registry into the `models` table in every environment, plus a confirmed `dev@example.com` / `password` user in development; an existing checkout needs `bin/rails db:seed`.
- `bin/dev` — app + Tailwind watcher. The job supervisor runs inside Puma, so there is no separate jobs process (see `docs/architecture/background-jobs.md`).
- `bin/rails test test/models/user_test.rb` — one file; `…_test.rb:42` runs that line's case, `-n test_the_name` one by name.
  **Gotcha:** SimpleCov demands 100% over the whole project, so any subset fails the gate at the end even when the asserts pass. While iterating use `SKIP_COVERAGE=1`.
- `bin/rails test:system` — Capybara + cuprite (headless Chrome over CDP), excluded from coverage, axe gate on every `visit`. `bin/rails test` does NOT include them.
- `bin/ci` — the pre-commit gate, exactly what CI runs. Rails' native CI runner, configured in `config/ci.rb` with eight steps: rubocop, brakeman, `bin/bundler-audit`, `i18n-tasks health`, `charco_mobile check`, `bin/rails test`, `bin/rails test:system`, `bin/smoke-rename`.
  **Gotcha:** two steps reach the network: `bin/bundler-audit` clones `rubysec/ruby-advisory-db` on first run and never refreshes it (no `--update`), and `bin/brakeman --ensure-latest` checks rubygems.org.
- `bin/rename <name>` — turn the template into a new app. `Template::Renamer` rewrites the name through the tree; `Template::Cleanup` (`lib/template/cleanup.rb`) then drops any remote pointing at the template's repo and deletes the template-only tooling.
  That tooling is `bin/rename`, `bin/smoke-rename`, `bin/spawn`, `bin/children`, `children.yml`, `lib/template/`, `test/lib/template/`, `docs/superpowers/` and the smoke step in `config/ci.rb`.
  It also rewrites the README's and this file's template-only sections, so a child app is not told about commands it no longer has — which is also what keeps the documentation gate green there.
  **Gotcha:** without that deletion an app is born with a red `bin/ci` — the renamer's own tests rewrite their fixtures into nonsense. `test/lib/template/cleanup_test.rb` guards it, and the README anchors it matches.
- `bin/smoke-rename` — the core promise end to end: export the tracked tree, rename it, assert no old-name reference survives, boot it, run the copy's unit suite, then serve the public pages over HTTP.
  Loading is not serving: `zeitwerk:check` catches a leftover constant but not a broken route or view.
  **Gotcha:** it exports tracked changes only, so a brand-new file must be `git add`ed before the smoke can see it.
  **Gotcha:** the local Bundler override lives in the gitignored `.bundle/config`, so the export resolves `charco_mobile` from git instead — a revision your own tree never materializes. After bumping the gem, `bundle install` in a throwaway export or smoke alone fails.
- `bin/spawn <name> [--github]` — clone into `../<name>`, bundle it, rename, detach, commit, register in `children.yml`. `--github` also creates and pushes a private repo, and sets its `CHARCO_MOBILE_DEPLOY_KEY` secret from `CHARCO_MOBILE_DEPLOY_KEY_PATH`, or prints the command when that is unset.
- `bin/children [synced <name> [sha]]` — report each child's pending template commits with a ready cherry-pick command, or record a child as synced.

All Ruby/Rails commands run under `mise exec ruby@4.0.6 -- <command>` in non-mise-shimmed shells (e.g. `mise exec ruby@4.0.6 -- bin/rails test`).

## Conventions
- TDD always: failing test first, minimal implementation second.
- Library-first: before writing anything, read the documentation of the gem that already solves it and use its documented way. Never reinvent what a library provides, and never keep our version of something the docs cover.
- Code, comments and identifiers stay English. No code comments. No inline styles.
- User-facing copy is NEVER hardcoded: it goes through `t(...)` and lives in `config/locales/es.yml` and `config/locales/en.yml` (Spanish default, English fallback). See `docs/architecture/i18n.md`.
- DaisyUI component classes before custom CSS.
- Controllers scope data through `Current.user` (see `ChatsController`, `DocumentsController`).
- LLM calls in tests use `stub_openai_chat` / `stub_openai_chat_stream` / `stub_openai_chat_stream_with_tool_call` / `stub_openai_embedding` (`test/test_helpers/openai_stubs.rb`).
- Background work goes to Solid Queue jobs (see `GenerateDocumentEmbeddingJob`). Solid Queue does NOT retry: declare `retry_on` if a job needs it.
- 100% line and branch coverage is enforced by SimpleCov; `bin/rails test` fails below 100%. Write the test first; never delete a failing coverage gate.
  `simplecov-console` prints the sub-100% files with their uncovered lines and branches on every run. Exclusions use `skip`, not the deprecated `add_filter`.
- N+1 queries fail tests: `Bullet.raise = true` in `config/environments/test.rb`, in every kind of test. Fix real ones with `includes`/`preload`/counter cache; safelist only a verified false positive, as narrowly as possible.
- Accessibility failures fail tests: `ApplicationSystemTestCase#visit` calls `assert_accessible` (`test/test_helpers/accessibility_helper.rb`), which audits axe-core against WCAG 2.1 A/AA in BOTH colour schemes, forced via the CDP `Emulation.setEmulatedMedia` command.
  Both is required, not thorough: headless Chrome's default scheme differs per machine. Fix the violation; never widen the ruleset.
- `axe-core-api` is installed only for its vendored `axe.min.js`; its own runner is Selenium-only, so `axe-core-capybara` is deliberately absent.
- User-facing business rules have exactly one owner: the code that enforces them. A rule the person needs to know — a grace period, a cancellation window, an eligibility threshold — is a constant (or a method) on the model that applies it.
  The sentence they read is generated from that value through i18n interpolation. Never restate the value as a literal in copy:

  ```ruby
  class Membership
    GRACE_PERIOD = 2.months
  end
  ```
  ```yaml
  es:
    memberships:
      rules:
        grace_period: "Con %{months} meses de atraso perdés los beneficios."
  ```

  Surface the same key in both places it is needed — a rules page for whoever wants to read them all, and a snippet in context where it actually matters (under the balance, next to the button that is disabled) — so saying it twice costs nothing and cannot diverge.
  The reason is not tidiness: a stated rule that drifts from the enforced one is not a stale doc, it is a broken promise to someone who paid. This is a convention, not a rules engine; reach for a real engine only when rules must change without a deploy, which is a much larger problem.
- Commits: short imperative messages, no co-author trailers.

## Documentation
Three places, three audiences. `README.md` is for whoever operates the app. This file is the map for agents: stack, commands, conventions, and an index. `docs/architecture/<subsystem>.md` is the detail for agents: what the subsystem is, where its code lives, and the gotchas that break it.

A doc is updated **in the same commit** as the behaviour it describes. A change to a subsystem that leaves its page untouched is an unfinished change, exactly like a change with no test.

Style: present tense, current state only. No history, no session narrative, no "previously" or "now". No code blocks — point at the file instead. One gotcha per paragraph, stated as a consequence rather than a warning.
Never write the app's name inside `docs/` — the renamer does not rewrite it, so it would survive into every app born from here.

`test/docs/documentation_test.rb` is the mechanical half: every page the map points at exists and every page is in the map, no line here exceeds 300 characters, and every file path any doc cites in backticks still exists, and is tracked: a spawned app is a clone, so an ignored file is absent there.
That last one is what makes "up to date" verifiable — a renamed file with a stale doc turns CI red.

## Subsystem map

Index. The full detail of each subsystem lives in `docs/architecture/<file>` —
**read the file before touching that subsystem**: nearly every one records a decision
verified against a library's source, and not knowing it is how they break.

- **Auth** — signup creates UNCONFIRMED users and sign-in blocks until confirmed; changing email or password needs the current password; deleting the account needs the exact i18n phrase AND the password. → `auth.md`
- **Data export** — automatic: every `dependent: :destroy` on `User` lands in the ZIP. An `encrypts`'d column comes out in PLAINTEXT — add it to `EXCLUDED_COLUMNS`. → `data-export.md`
- **Email** — active provider-agnostic SMTP. Without `APP_HOST` every mailer link points at `example.com`. → `email.md`
- **AI chat** — `@messages` needs its four-association `includes` or Bullet fails the test; the update broadcast is an APPEND because Action Cable reorders; the daily quota lives on `User`. → `ai-chat.md`
- **Semantic search** — the embedding callback is guarded by the SOURCE having changed, or it re-enqueues itself forever. A non-empty `models` table IS the registry: seed it or the embedding model is unknown. → `semantic-search.md`
- **Rich text** — on Rails 8.1 Lexxy monkey-patches `rich_text_area`; re-check `Lexxy.supports_editor_adapter?` after every upgrade. → `rich-text.md`
- **Console auditing** — console1984 depends on Active Record encryption; a new app must generate its own credentials. → `console-auditing.md`
- **Superadmin panels** — one concern gates eight surfaces. **Deny-by-default**: unconfigured means 401 everywhere, never open. → `superadmin-panels.md`
- **Design** — DaisyUI themes in OKLCH, warm neutral with one accent. The accessibility gate decides the palette, and the NEUTRALS fail before the accent does. → `design.md`
- **Documentation site** — `/docs` renders these pages with Redcarpet. `Doc.find` matches a listed slug, so traversal is impossible by construction. → `docs-site.md`
- **Background jobs** — Solid Queue runs INSIDE Puma in development too, so `Procfile.dev` has no jobs line. No automatic retries: a failed job sits in the failed-executions table. → `background-jobs.md`
- **Analytics** — capability only, zero events tracked. Two wiring details (`Ahoy.user_method`, the callback reorder) fail SILENTLY if touched. → `analytics.md`
- **Health checks** — `/up` stays shallow (Kamal gates deploys on it), `/health` is the deep one. The supervisor reports `Supervisor(fork)`, never `Supervisor`: match with `LIKE`. → `health-checks.md`
- **Error tracking** — Solid Errors subscribes to `Rails.error` and deduplicates into the primary DB; dashboard at `/errors`. `/error_feed` hands new errors to an outside watcher behind a bearer token, `404` until one is set. → `error-tracking.md`
- **User feedback** — always persists locally; the GitHub issue is optional and never blocks. Nothing retries it. → `user-feedback.md`
- **Support chat** — **BINDING RULE: nothing technical may ever reach the person.** The column is `ticket_context`, NOT `context` (it would shadow `acts_as_chat`'s). Photos: `detach`, never `purge`. → `support-chat.md`
- **Ticket lifecycle** — `Feedback#resolve!` is idempotent and closes the conversation it came from; panel at `/admin/feedbacks`, no notifications. → `ticket-lifecycle.md`
- **Notifications** — noticed keeps the event/notification split and `deliver_by :database` is a deprecated no-op. Zero notifiers ship. → `notifications.md`
- **Log viewer** — `default_log_file_path` MUST stay empty: with a real path the channel streams it with no whitelist check. → `log-viewer.md`
- **Authorization** — pundit as capability only, zero policies; `pundit_user` is overridden to `Current.user`. → `authorization.md`
- **i18n** — Spanish default, English fallback, no switcher. Copy is NEVER hardcoded: the key goes in BOTH yml files, then `bin/i18n-tasks normalize`. Tests assert keys, never copy. → `i18n.md`
- **Blog / content** — RailsPress is back-office only; the public `/blog` is this app's. The admin gate is the per-app seam. `Post#excerpt` does NOT exist. → `blog.md`
- **Browser errors** — JS errors land at `/errors` next to server ones. The CSRF token is attached when present, never required. → `browser-errors.md`
- **Sitemap / robots** — dynamic, not static: `Sitemap:` needs an absolute URL and a file in `public/` cannot know its host. → `sitemap-robots.md`
- **Deploy** — Kamal; UPPERCASE placeholders, and the `storage/` volume is mandatory (SQLite + Active Storage). → `deploy.md`
- **Backups** — the restic accessory is ACTIVE: it refuses to boot until the repository and secrets are set. Deliberate. → `backups.md`
- **Security headers / CSP** — nonce-based CSP active in every environment: scripts strict, styles inline. → `security-headers.md`
- **Mobile apps** — `charco_mobile` signals in the layout and form pages; a mistyped signal is SILENTLY ignored, so `charco_mobile check` runs in CI. Push tokens land on `User#push_devices`; `config/push.yml` needs real credentials before anything is delivered. → `mobile.md`
- **Templates** — `Herb::Engine` intercepts every `.html.erb`; malformed HTML is a compile-time error, not a silent render. Reactive templates (`slots`) are NOT adopted. `herb analyze` (Ruby-native, no Node) gates `bin/ci`; `herb lint`/`format` need Node, which this stack doesn't have. → `templates.md`
