# CharcoTemplate

Rails starter template. This repo is both a working app and the template new apps are born from (`bin/rename <new_app_name>` after cloning).

## Stack
- Ruby 4.0.6, Rails 8.1.3.1, SQLite everywhere (Solid Queue/Cache/Cable). Propshaft + Importmap, no Node.
- Tailwind v4 + DaisyUI 5 vendored in `app/assets/tailwind/`, Hotwire, Lexxy rich text, Herb renders every `.html.erb`, Lucide icons.
- RubyLLM on OpenAI only, Schematist for structured output, Neighbor + sqlite-vec for vector search.
- Native Rails auth, console1984, money-rails, pagy, noticed, pundit, ahoy. The last three are capability only: nothing uses them yet.
- Developer panels behind one shared basic auth. RailsPress is the blog back-office; the public `/blog` is ours.
- Spanish default, English fallback. Locale from a cookie the navbar switcher sets, else `Accept-Language`. `charco_mobile` drives native iOS and Android apps.
- Minitest + fixtures + WebMock, cuprite system tests, axe-core, bullet, SimpleCov at 100%. Kamal deploys.

## Commands
Run Ruby commands as `mise exec ruby@4.0.6 -- <command>` in shells without mise shims.

- `bin/setup` — install and prepare. Seeds only on first creation (`db/seeds.rb`: the model registry, plus `dev@example.com` / `password` in development); an existing checkout runs `bin/rails db:seed`.
- `bin/dev` — app, Tailwind watcher and `herb dev`, which reloads the page when a template changes. The job supervisor runs inside Puma, so there is no jobs process.
- `bin/rails test test/models/user_test.rb:42` — one file or one case. Prefix `SKIP_COVERAGE=1`: the 100% gate fails any subset.
- `bin/rails test:system` — cuprite + axe. `bin/rails test` does not include it.
- `bin/ci` — the pre-commit gate, exactly what CI runs (`config/ci.rb`, ten steps: rubocop, brakeman, `bin/bundler-audit`, `i18n-tasks health`, `charco_mobile check`, `herb analyze`, `archspec check`, `bin/rails test`, `bin/rails test:system`, `bin/smoke-rename`).
- `bin/rename <name>` — turn the template into an app: rewrite the name in tracked files, then delete the template-only tooling and rewrite this file and the README.
  Without that deletion the app is born with a red `bin/ci`; `test/lib/template/cleanup_test.rb` guards it.
- `bin/smoke-rename` — export the tracked tree, rename it, boot it, run its unit suite, serve its public pages.
  It exports tracked files only: `git add` a new file first.
- `bin/spawn <name> [--github]` — clone into `../<name>`, rename, commit, register in `children.yml`; `--github` also creates a private repo.
- `bin/children [synced <name> [sha]]` — show each child's pending template commits, or record a child as synced.

## Conventions
Reasons and examples: `docs/architecture/conventions.md`.

- TDD: failing test first. 100% line and branch coverage; never weaken the gate.
- Library first: read the gem's docs and use its documented way.
- Code, comments and identifiers in English. No code comments. No inline styles. DaisyUI classes before custom CSS.
- Copy is never hardcoded: `t(...)`, with the key in `config/locales/es.yml` AND `config/locales/en.yml`.
- Controllers scope data through `Current.user`.
- Tests never hit the network; stub LLM calls with `test/test_helpers/openai_stubs.rb`.
- `Archspec.rb` is the architecture: rich models, no service layer, jobs never read `Current`. Fix a violation; never silence it.
- Background work is a Solid Queue job. Nothing retries unless the job declares `retry_on`.
- N+1 queries and accessibility violations fail tests. Fix them; never widen a safelist or a ruleset.
- A business rule the person reads is a constant on the model that enforces it, interpolated into the copy, never restated.
- Commits: short imperative subject, no co-author trailers.

## Documentation
- `README.md` is for operators. This file is the agents' map. `docs/architecture/<page>.md` is the detail: read it before touching that subsystem.
- Update the page in the same commit as the behaviour. Present tense, current state only, no code blocks, one gotcha per paragraph.
- Never write the app's name in `docs/`, and never cite template-only tooling there: a spawned app deletes it.
- `test/docs/documentation_test.rb` checks the map matches the pages, lines here stay under 300 characters, and every cited path is tracked.

## Subsystem map
- **Conventions** — the reasons behind each rule above, and the business-rule pattern. → `conventions.md`
- **Testing** — `bin/bundler-audit` and `bin/brakeman` reach the network; a hanging system run is a crashed worker. → `testing.md`
- **Auth** — sign-in blocks until the email is confirmed; email or password changes need the current password. → `auth.md`
- **Data export** — every `dependent: :destroy` on `User` lands in the ZIP; an `encrypts`'d column comes out in PLAINTEXT. → `data-export.md`
- **Email** — without `APP_HOST` every mailer link points at `example.com`. → `email.md`
- **AI chat** — `@messages` needs its `includes` or Bullet fails; the update broadcast is an APPEND on purpose. → `ai-chat.md`
- **Semantic search** — the embedding callback is guarded by its source changing, or it re-enqueues forever. → `semantic-search.md`
- **Rich text** — Lexxy monkey-patches `rich_text_area` on Rails 8.1; re-check after every upgrade. → `rich-text.md`
- **Console auditing** — needs Active Record encryption; a new app generates its own credentials. → `console-auditing.md`
- **Superadmin panels** — one concern gates eight surfaces, deny-by-default: unconfigured means 401. → `superadmin-panels.md`
- **Design** — the accessibility gate decides the palette, and the neutrals fail first. → `design.md`
- **Documentation site** — `/docs` renders these pages; `Doc.find` only matches listed slugs. → `docs-site.md`
- **Background jobs** — Solid Queue runs inside Puma; a second supervisor runs every job twice. → `background-jobs.md`
- **Analytics** — zero events tracked; `Ahoy.user_method` and the callback order fail SILENTLY if touched. → `analytics.md`
- **Health checks** — `/up` stays shallow for Kamal; the supervisor `kind` is `Supervisor(fork)`, so match with `LIKE`. → `health-checks.md`
- **Error tracking** — Solid Errors at `/errors`; `/error_feed` answers 404 until its token is set. → `error-tracking.md`
- **User feedback** — always saved locally; the GitHub issue is optional and never retried. → `user-feedback.md`
- **Support chat** — nothing technical may reach the person; the column is `ticket_context`, never `context`. → `support-chat.md`
- **Ticket lifecycle** — `Feedback#resolve!` is idempotent and closes the source conversation. → `ticket-lifecycle.md`
- **Notifications** — zero notifiers ship; `deliver_by :database` is a deprecated no-op. → `notifications.md`
- **Log viewer** — `default_log_file_path` MUST stay empty, or the channel streams it unchecked. → `log-viewer.md`
- **Authorization** — zero policies ship; `pundit_user` is `Current.user`. → `authorization.md`
- **i18n** — a key goes in BOTH locale files, then `bin/i18n-tasks normalize`; tests assert keys, never copy. → `i18n.md`
- **Blog / content** — the admin gate is the per-app seam; `Post#excerpt` does not exist. → `blog.md`
- **Browser errors** — JS errors land at `/errors`; the CSRF token is sent when present, never required. → `browser-errors.md`
- **Sitemap / robots** — dynamic, because `Sitemap:` needs an absolute URL. → `sitemap-robots.md`
- **Deploy** — Kamal with UPPERCASE placeholders; the `storage/` volume is mandatory. → `deploy.md`
- **Backups** — the restic accessory refuses to boot until its repository and secrets are set. → `backups.md`
- **Security headers / CSP** — strict nonce-based scripts, inline styles allowed, in every environment. → `security-headers.md`
- **Mobile apps** — a mistyped native signal is SILENTLY ignored, so `charco_mobile check` runs in CI. → `mobile.md`
- **Templates** — Herb makes malformed HTML a compile-time error; `herb lint` and `format` need Node. → `templates.md`
- **Pagination** — pagy's own translator ignores `I18n.with_locale`, so it goes through Rails I18n. → `pagination.md`
- **Money** — money-rails configured, nothing monetized; apps opt in per model. → `money.md`
