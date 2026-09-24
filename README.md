# CharcoTemplate

## What is this

CharcoTemplate is a Rails 8.1.3.1 starter template. It is a fully working app on its own, and it is also the seed you clone to start a new project (`bin/rename <new_app_name>` rewrites the app's name throughout the codebase). Everything described below already exists in this repo — clone it, rename it, and build on top.

## Features

- Native Rails authentication (sign up, sign in/out, password reset) plus a custom registration flow, email confirmation on signup, self-service account deletion (right to erasure) and data export (right to portability), and a profile page
- Avatars via Active Storage variants, with an initials fallback when no avatar is uploaded
- An AI chat UI (RubyLLM + OpenAI) scoped per signed-in user, with streaming responses and automatic chat titling
- A `Document` model with Lexxy rich text editing and semantic search over embeddings (Neighbor + sqlite-vec)
- Solid Queue, Solid Cache and Solid Cable — all on SQLite, no Redis required
- console1984: every production Rails console session and command is recorded
- Solid Errors: uncaught exceptions are captured and deduplicated in SQLite, with a dashboard behind HTTP basic auth
- onlylogs: a self-hosted log viewer at `/onlylogs` behind HTTP basic auth, tailing a rotated, size-capped copy of the production log on the storage volume
- A signed-in feedback form that always saves locally and, when configured, opens a labeled GitHub Issue
- A floating AI support assistant that turns a conversation into a refined, human-friendly ticket, filed through the same feedback pipeline
- A blog / CMS (RailsPress): an authoring back-office at `/railspress/admin` and a reader-facing blog at `/blog` styled with DaisyUI
- Tailwind v4 + DaisyUI 5 (vendored, no Node/npm needed), Hotwire (Turbo + Stimulus)
- Lucide icons rendered inline through a helper, no icon font or CDN
- Kamal deployment configuration ready to point at your own server

## Requirements

- [mise](https://mise.jdx.dev) (or another way to install Ruby 4.0.6 matching `.ruby-version`)
- Ruby 4.0.6
- libvips (used by Active Storage's `image_processing` gem for avatar variants)
- An OpenAI API key (for the AI chat and semantic search features)

All Ruby/Rails commands below run under `mise exec ruby@4.0.6 --` in non-mise-shimmed shells (e.g. `mise exec ruby@4.0.6 -- bin/rails test`); the examples show bare commands for readability.

## Quickstart

```bash
git clone <this-repo> my_app
cd my_app
bundle install
bin/rename my_app
bin/setup
```

`bin/rename` does two things: it rewrites the app's name throughout the tree, and then **removes the tooling that only serves the template** — itself, `bin/smoke-rename`, `bin/spawn`, `bin/children`, `children.yml`, `lib/template/`, their tests, the smoke step in `config/ci.rb`, this repo's own planning documents under `docs/superpowers/`, and the template-specific parts of this README and of `CLAUDE.md`. An app has no use for a tool that renames it again, and carrying the renamer's unit tests is worse than useless: renaming rewrites their fixtures into nonsense and the app is born with a red `bin/ci`.

New apps need their own credentials — `config/master.key` is gitignored on purpose and never travels with the repo, and console1984 depends on Active Record encryption keys that live inside `config/credentials.yml.enc`. Before running the app for real, regenerate both:

```bash
rm config/credentials.yml.enc
bin/rails credentials:edit
```

This creates a fresh `master.key` and a new encrypted credentials file (Rails' default scaffold, with a freshly generated `secret_key_base`), and opens it in your editor. Then generate new Active Record encryption keys:

```bash
bin/rails db:encryption:init
```

Copy the three printed keys (`primary_key`, `deterministic_key`, `key_derivation_salt`) into an `active_record_encryption:` block inside the credentials file (`bin/rails credentials:edit` again), then save.

Finally, start the app:

```bash
bin/dev
```

`bin/dev` runs two processes side by side (see `Procfile.dev`): the Rails server and the Tailwind watcher. The Solid Queue supervisor runs inside Puma, so it comes up with the server — see [Background jobs](#background-jobs), and note that the queue logs to `log/development.log`, not to your terminal.

`db:prepare` seeds the database only the first time it creates it, so a fresh clone signs in with `dev@example.com` / `password`. On an existing checkout — the database already exists — run `bin/rails db:seed` to get that user; the same seed loads RubyLLM's model registry into the `models` table, which the AI chat and semantic search need once the table is no longer empty.

## Starting a new app

Each item below is documented in depth in its own section — this is the order to do them in, and the list of things nobody else can do for you.

**Before you write code**

1. From inside this template's own directory: `bin/spawn my_app [--github]`. It clones the template into `../my_app`, runs `bin/rename` inside the clone, removes the clone's `origin` remote (so the new app has *no* remote at all — deliberate: it must never be able to push into the template it came from), commits the rename, and registers the app in the template's `children.yml` for later cherry-picks. Pass `--github` to also create and push a private GitHub repo for it; without the flag, `bin/spawn` prints that same `gh repo create` command for you to run whenever you're ready. Then, inside `../my_app`: `bin/setup`, and regenerate credentials plus Active Record encryption keys — see [Quickstart](#quickstart) above. The app will not run for real until you do.
2. **If you skipped `--github`, give the app its own repository now.** Do this on day one. Commits pile up fast and a clean `git log` looks identical whether or not it exists anywhere but your disk. To port an improvement from the template later you do not need a permanent remote — fetch it on demand:

   ```bash
   git fetch https://github.com/bruno-costanzo/rails-template main
   git cherry-pick <sha>
   ```

   Cherry-pick rather than copying files: where both repos changed the same file — `config/routes.rb`, the locale files, `db/schema.rb` — git stops and asks instead of silently overwriting your work.
3. Put `OPENAI_API_KEY` in `.env` if this app uses the AI chat, semantic search or support assistant — see [Configuration](#configuration).
4. **Delete what this app will not use.** The template ships a blog, an AI chat, documents with semantic search and a support assistant; an app that needs none of them should carry none of them. Whatever you remove, remove from the screen list in `docs/design-substrate.md` too.
5. **Design system.** Connect *this app's* repo — pruned, not the template's — to your design tool, paste `docs/design-substrate.md` unchanged, and fill in `docs/brand-brief-template.md`. What comes back is a DaisyUI theme block that goes into `app/assets/tailwind/application.css`. See [Accessibility](#accessibility) for the contrast rules the theme has to satisfy: the audit runs on every system test, in both colour schemes.
6. **Decide what is worth measuring** and add the events — see [Analytics](#analytics). The template ships the plumbing and zero events on purpose.

**Before you deploy**

7. `APP_HOST` and the SMTP secrets — see [Email](#email). Without them every mailer link and feedback photo link points at `example.com`.
8. `SUPERADMIN_USER` and `SUPERADMIN_PASSWORD` — see [Superadmin access](#superadmin-access). Deny-by-default: while they are unset, every developer panel answers `401`.
9. Replace the `YOUR_*` placeholders in `config/deploy.yml` — see [Deployment](#deployment).
10. Set `restic.repository` in `config/kamal-backup.yml` and uncomment the backup secrets in `.kamal/secrets` — see [Backups](#backups). **The backup accessory is active by default, so the deploy fails until you do this.** That is deliberate: decide about backups before there is real data to lose.

**After you deploy**

11. Point an uptime monitor at `https://your-app/health` — see [Health checks](#health-checks). The endpoint exists and reports on the database and the job supervisor, but nothing watches it until you wire a monitor up. This is the one piece that cannot live in the template.
12. Set `ERROR_FEED_TOKEN` and hand the same token to the watcher — see [Error feed](#error-feed). Until it is set, nothing outside the app can read its errors.

## Configuration

Copy `.env.example` to `.env` and fill in your own key:

```bash
cp .env.example .env
```

```
OPENAI_API_KEY=sk-your-key-here
```

`.env` is gitignored; `.env.example` (checked in) documents the required variables. `.env.test` carries a fake test key (`OPENAI_API_KEY=test-key`) so the app boots in the test environment before WebMock installs its network stubs.

The chat and embedding model names are also configurable, via `OPENAI_CHAT_MODEL` and `OPENAI_EMBEDDING_MODEL` (`config/initializers/ruby_llm.rb`), defaulting to `gpt-4o-mini` and `text-embedding-3-small`. Swapping the embedding model is not just an ENV change: `Document::EMBEDDING_DIMENSIONS = 1536` is tied to `text-embedding-3-small`'s output size, so a different embedding model needs a migration to match its dimension — plan for that before overriding it.

### Mobile apps

The app is born ready to ship as native iOS and Android apps through the [charco_mobile](https://github.com/bruno-costanzo/charco_mobile) gem. `config/charco_mobile.yml` declares the tab bar, the colors and the error screens; the views describe the rest with `native_*` helpers, and the native shells read it from every page. Nothing in Swift or Kotlin is written per app.

To preview on a phone, run the server and the tunnel in two terminals, then scan the QR code with the preview app:

```bash
bin/rails server
bundle exec charco_mobile preview
```

`bundle exec charco_mobile check` parses every view and reports signals the apps would silently ignore; `bin/ci` runs it. The gem is a private repository reached over SSH, so GitHub Actions needs the `CHARCO_MOBILE_DEPLOY_KEY` secret: the read-only deploy key registered on that repository. A new app's repository needs the same secret before its first CI run.

### Email

Signing up requires **email confirmation**. A new account is created unconfirmed and **cannot sign in until it confirms** — registration sends a confirmation link (`EmailConfirmationsMailer`) and redirects to the sign-in page with a "check your email" notice; `SessionsController#create` rejects sign-in until `user.confirmed?`. Clicking `GET /email_confirmations/:token` confirms the account (the token, from `User.generates_token_for :email_confirmation`, expires in a day and is tied to the address). There's a resend form at `/email_confirmations/new` (rate-limited, and it never reveals whether an address exists). This block-until-confirmed behavior is the strict default; to allow sign-in but keep the account marked unconfirmed instead, change the `user.confirmed?` guard in `SessionsController#create`.

A signed-in user can **delete their own account** from the profile page's "Danger zone". Deleting is deliberately hard to do by accident *and* requires proving identity: you type an exact confirmation phrase — **`I WANT TO DELETE MY ACCOUNT`** (`QUIERO BORRAR MI CUENTA` in Spanish; the page shows the phrase for your locale) — **and** re-enter your current password. Get either wrong and nothing is deleted (you're sent back to the profile with an error). On success the deletion is permanent and irreversible: the account and everything it owns — sessions, chats, documents, feedback, notifications, and the avatar — are cascade-deleted (`Current.user.destroy`), your session is ended, and you land back on the sign-in page. It's a true erasure, not a soft delete. (One thing the cascade doesn't touch: if you enable RailsPress authors, a deleted user's blog posts keep their `author_id` — decide per app whether to nullify or remove them.)

The mirror image of deletion is **data export** (portability): from the same profile page a user can request a **ZIP of all their data**. It runs **asynchronously** — you click "Export my data", the app builds the archive in the background (it can be large — think years of attachments), then emails you a link; clicking it downloads the ZIP (you must be signed in — a full-account archive never hangs off a shareable link). What goes in is defined the DRY way: the export walks the *same* set of records the deletion cascade would erase (so "what gets deleted" and "what gets exported" can't drift apart), dumps each as JSON, and packs every attached file under `files/`. Two things are excluded by default for safety/quality — your password hash (`password_digest`, which must never leave the app even to you) and document embedding vectors (machine noise, not human data); add your own exclusions in `app/models/data_export.rb` (`EXCLUDED_COLUMNS` / `EXCLUDED_ATTACHMENTS`). Any model you later hang off `User` with `dependent: :destroy` is picked up automatically by both features, and Action Text rich text (like a document's body) is exported as plain text alongside the record's columns. (Current limitation: rich-text *formatting* and files *embedded inside* rich text aren't included — only the text itself.)

**A note on encrypted fields.** If you encrypt a column with Active Record Encryption (`encrypts :notes`), the export contains its **decrypted, plaintext** value — which is what portability requires (the person gets readable data, not ciphertext). Two consequences to keep in mind: any field that's encrypted because it's a *secret the app holds* rather than the user's own content (an API token, a TOTP secret) should be added to `EXCLUDED_COLUMNS` just like the password hash already is; and because the generated ZIP is decrypted-at-rest, it is not kept around — an export expires 48 hours after it's built (`DataExport::RETENTION`), the download refuses to serve a stale one, and an hourly background task purges expired exports in production.

For production delivery, the template ships an active, **provider-agnostic SMTP scaffold** in `config/environments/production.rb` — you only fill the secrets. It reads `Rails.application.credentials.dig(:smtp, :user_name)` / `:password` first, then falls back to environment variables, so pick either:

```
APP_HOST=your-app.com
SMTP_ADDRESS=smtp.your-provider.com
SMTP_PORT=587
SMTP_USER_NAME=your-smtp-username
SMTP_PASSWORD=your-smtp-password
```

`APP_HOST` is the domain used in mailer links (and feedback photo links) — **set it before deploying**, or they fall back to the `example.com` placeholder. `SMTP_*` work with any provider (SendGrid, Postmark, Mailgun, SES, Resend, …); prefer storing the username/password in credentials (`smtp/user_name`, `smtp/password`) over `.env`. Choosing a provider and its credentials is a per-app decision — the template ships the wiring, not the secrets. In development, email is not sent — it's caught in the [letter_opener_web](#development-email-preview) inbox at `/letter_opener`; tests use the `:test` delivery method.

## Internationalization

The UI is bilingual. **Spanish is the default; English is served when the visitor's browser prefers it** — the locale is read from the `Accept-Language` header on every request (`ApplicationController#set_locale`), picking the first language it recognizes (`es`/`en`) and otherwise falling back to Spanish. There is **no in-app language switcher, and the locale is not user-configurable** — that's deliberate: you get English only if your browser is set to English. Framework strings (dates, numbers, Active Record error messages) come from the `rails-i18n` gem; `config/application.rb` sets `default_locale = :es`, `available_locales = [:es, :en]`, and `fallbacks = [:en]`.

No user-facing copy is hardcoded — it all lives in `config/locales/es.yml` and `config/locales/en.yml`, which are kept perfectly in sync. Two gates enforce that, in the same spirit as the coverage and N+1 gates:

- `config.i18n.raise_on_missing_translations = true` (in `config/environments/test.rb`): a `t()` lookup with a missing key raises during the test suite, so an untranslated string fails the build.
- An `i18n-tasks health` step in `config/ci.rb` (configured in `config/i18n-tasks.yml`) fails CI on any missing key, unused key, or inconsistent interpolation between the two locales.

There is intentionally no static "hardcoded string in a view" linter — no maintained tool detects literal text inside ERB reliably, so a fragile one was left out; the two gates above plus review cover it.

To add a new string: wrap it in a translation lookup (views use the lazy form `t(".key")`, which resolves to `<controller>.<action>.key`), add that key to **both** `config/locales/es.yml` and `config/locales/en.yml`, then run `bin/i18n-tasks normalize` to canonicalize the files (and `bin/i18n-tasks health` to confirm the two locales are in sync). Tests assert against `I18n.t(key)` rather than English literals, so they stay locale-independent.

## Testing

Run `bin/ci` before every commit — it is the pre-commit gate and exactly what CI runs. It's Rails' native CI runner, configured in `config/ci.rb`: rubocop, brakeman, `bin/bundler-audit`, `i18n-tasks health`, `bin/rails test`, `bin/rails test:system`, and a `bin/smoke-rename` step.

`bin/bundler-audit` checks the locked gems against `rubysec/ruby-advisory-db`, which the gem does not vendor: the first run `git clone`s it into `~/.local/share/ruby-advisory-db` (needs network), and every later run — since the binstub never passes `--update` — reuses whatever copy is already on disk, however old. This isn't offline or deterministic, but CI already needs network for `bundle install`, so the fetch is accepted rather than worked around; if a security scan must reflect a specific point in time, cache or pin `~/.local/share/ruby-advisory-db` explicitly. `bin/brakeman --ensure-latest` — Rails' own generated binstub, not something this template added — likewise reaches rubygems.org on every run and can fail CI on the day brakeman ships a new release, unrelated to any code change here.

```bash
bin/ci
```

That last step is a **smoke test of the template's core promise** — that you can clone this repo, rename it, and get an app that boots *and serves*. It exports the tracked tree to a temp dir, runs `bin/rename smoke_app` on it, asserts no reference to the old name survived anywhere in the tree, boots the renamed copy with `db:prepare` + `zeitwerk:check` so a single leftover `CharcoTemplate` constant fails loudly, and then **starts a real server and requests the public pages**: `/`, `/session/new`, `/registration/new`, `/blog`, `/sitemap.xml`, `/robots.txt`, plus `/health` (asserting the body reports a healthy database — `jobs` is legitimately down there, since no supervisor runs alongside).

It also **runs the renamed copy's own test suite**, which is the check that matters most: the template's promise is not just that a new app boots, but that its quality gates are green on day one. Loading is not serving, and passing is not the same as being checkable: `zeitwerk:check` catches a leftover constant, a real request catches a broken route or a view calling a helper that no longer exists, and running the copy's suite catches a test that renaming turned into nonsense. It reuses the existing bundle (renaming never touches the `Gemfile`), so the whole step costs a few seconds. The boot doesn't decrypt credentials, so it needs no master key — locally, if `config/master.key` is present it's copied into the copy as a safety belt, but CI (where the key is absent) still passes. Override the port with `SMOKE_PORT` if 3987 is taken.

Tests never hit the network. `test/test_helper.rb` calls `WebMock.disable_net_connect!(allow_localhost: true)`, so any real HTTP call from a test fails loudly instead of silently reaching OpenAI. Stub RubyLLM calls with the helpers in `test/test_helpers/openai_stubs.rb`:

- `stub_openai_chat(content:)` — stubs a chat completion
- `stub_openai_chat_stream(chunks:)` — stubs a streamed chat completion
- `stub_openai_chat_stream_with_tool_call(tool_name:, arguments:, chunks:)` — stubs a streamed tool-call round trip (a tool-call chunk, then a final streamed reply)
- `stub_openai_embedding(vector:)` — stubs an embedding request

### System tests

System tests (`bin/rails test:system`) drive a real headless Chrome through **cuprite** (Ferrum/CDP), configured in `test/application_system_test_case.rb`. Cuprite talks to Chrome directly over the DevTools protocol rather than through a WebDriver/chromedriver layer, which delivers clicks and keystrokes reliably — Selenium's synthetic input dropped intermittently on the CI runner and made these tests flaky. Because input is reliable, the tests use plain Capybara (`click_button`, `fill_in`, `find(...).click`) with no `execute_script` workarounds. `Capybara.disable_animation = true` is set so DaisyUI transitions never intercept an interaction. The CI runner already ships Chrome; no extra install step is needed.

### Coverage

100% line and branch coverage over `app/` and `lib/` is enforced by SimpleCov and measured on the `bin/rails test` (unit/integration) run. `test/test_helper.rb` sets `minimum_coverage line: 100, branch: 100`, so the suite fails the moment either number drops below 100%. Write the test that closes the gap first; never delete or weaken a failing coverage gate to make it pass. System tests (`bin/rails test:system`) are excluded from measurement — they run with `SKIP_COVERAGE=1` set (see `test/application_system_test_case.rb` and the system step in `config/ci.rb`), since browser-driven tests would otherwise double-count or skew the coverage figures gathered from the unit/integration run.

When coverage drops below 100%, you don't have to open the HTML report to find the gap: `simplecov-console` prints a table to the terminal listing each file under 100% with the exact **uncovered line numbers** (its `missing` column) and uncovered branches, so `bin/rails test` tells you precisely what to cover.

### N+1 detection

The `bullet` gem watches every query the test suite issues and fails the test the moment it spots an N+1 (an association lazily loaded once per record instead of eager-loaded once for the batch) or an eager load that was requested but never used. It's enabled strictly: `config/environments/test.rb` sets `Bullet.enable = true` and `Bullet.raise = true`, so a detected N+1 on any test-exercised path is a red test, not a log line. `config/environments/development.rb` enables it non-fatally instead (`Bullet.rails_logger = true`, `Bullet.console = true`) — it logs to `log/bullet.log` and to the browser console while you develop, without raising.

`test/test_helper.rb` wraps every test (not just controller/integration ones) with `Bullet.start_request`/`Bullet.end_request` in `before_setup`/`after_teardown`, exactly as Bullet's Minitest integration doc recommends. Controller, integration, and system tests already get this for free from Bullet's own Rack middleware (auto-inserted by its Railtie), but plain model/unit tests that touch associations directly do not go through that middleware, so the explicit wrapping is what makes strict mode apply everywhere. System tests are covered too: they run against a real in-process Puma server, Bullet's middleware wraps each request on that server thread the same way it does in production, and Capybara's `raise_server_errors` (on by default) re-raises the exception in the test thread — verified empirically by reverting a known eager load and watching a system test fail with the `Bullet::Notification::UnoptimizedQueryError`.

When a test fails with `Bullet::Notification::UnoptimizedQueryError`, the message tells you exactly what to do: "USE eager loading detected ... Add to your query: .includes([...])" means a real N+1 — add the suggested `includes`/`preload`, or a counter cache if it says "Need Counter Cache". "AVOID eager loading detected ... Remove from your query: .includes([...])" means an eager load that this particular code path never used — either the `includes` is genuinely unnecessary and should be removed, or it's necessary for a different caller than the one this test exercises. The stack trace under the message points at the exact model, association, and call site.

Only add an entry to the safelist (`Bullet.add_safelist`) when you've verified the second case: the eager load is correct for its real call site, just not exercised by this particular test. Keep the entry as narrow as possible — exact `class_name` and `association`, never a blanket disable of a detector. For example, `NotificationsHelperTest` calls `recent_notifications` (which does `.includes(:event)`) without ever rendering a notification's `message`, so Bullet sees the eager load as unused in that one test even though the navbar bell partial that calls `recent_notifications` in production always renders `message` (which delegates to `event`). That's safelisted narrowly in `config/environments/test.rb`:

```ruby
Bullet.add_safelist type: :unused_eager_loading, class_name: "TestNotifier::Notification", association: :event
```

### Accessibility

Every `visit` in a system test audits the rendered page with **axe-core** against the WCAG 2.1 A and AA rulesets, and any violation fails the test. The audit lives in `test/test_helpers/accessibility_helper.rb` (`assert_accessible`) and is wired into `ApplicationSystemTestCase#visit`, right after `assert_turbo_ready`, so it is automatic rather than opt-in — the same stance as the coverage and Bullet gates: you cannot forget to call it, and a regression is a red test rather than a report someone has to read. It costs roughly 1.2s across the whole system suite (about 7%), because axe is injected once per page load and Turbo keeps `window.axe` alive across in-page navigations.

A failure names the rule, its impact, the Deque help URL, and the offending selectors:

```
2 accessibility violations on /support_chat:

  label (critical) — Form elements must have labels
    https://dequeuniversity.com/rules/axe/4.13/label
    #chat_pending_photos
```

**Only `axe-core-api` is installed, and only as the delivery vehicle for the vendored `axe.min.js`.** The gem's own runner is unusable here: its default path (`Axe::API::Run#analyze_post_43x`) is Selenium-specific — it calls `manage.timeouts`, `switch_to.window`, and rescues `Selenium::WebDriver::Error` — and even its legacy path calls `execute_async_script`, which cuprite does not implement (cuprite exposes `evaluate_async_script`). So the helper injects `Axe::Configuration.instance.jslib` and drives `axe.run` through Capybara's own `evaluate_async_script`. The companion `axe-core-capybara` gem is deliberately **not** installed: its only entry point forces `Capybara::Selenium::Driver` and requires `selenium-webdriver`, which is not in this bundle.

Two environment facts worth knowing before you read a result:

- **The CSP does not block the audit.** axe is injected over the DevTools protocol, which is not subject to the page's `script-src 'self'` policy. No nonce or policy relaxation is needed.
- **Every page is audited twice, once per colour scheme.** `assert_accessible` drives Chrome's `Emulation.setEmulatedMedia` over CDP to force `prefers-color-scheme: light` and then `dark`, running axe against each, and resets the emulation afterwards. The failure message names the scheme. This is not a nicety: headless Chrome's default scheme differs between machines — locally it reported `dark` while the GitHub Actions runner reported `light` — so a single-scheme audit passed on one and failed on the other. Auditing both makes the gate deterministic and removes the blind spot, at a cost of roughly 5s across the system suite.

That second fact surfaced a real defect: **DaisyUI 5's default dark theme does not meet WCAG AA** — `--color-primary-content` on `--color-primary` measures 4.12:1 where 4.5:1 is required, so any `chat-bubble-primary` (or other primary-on-primary text) fails. `app/assets/tailwind/application.css` overrides just that one token back to white, which measures 4.66:1:

```css
@plugin "./daisyui-theme.mjs" {
  name: "dark";
  prefersdark: true;
  color-scheme: dark;
  --color-primary-content: oklch(100% 0 0);
}
```

Declaring a theme by the name of a built-in one merges over it (`{ ...builtinTheme, ...customThemeTokens }` in `daisyui-theme.mjs`), so every other token keeps its default. The lesson generalises to any theme an app ships: semantic tokens buy consistency, not contrast. Verify every color/`-content` pair against AA when you replace this theme.

The mounted engine panels (`/madmin`, `/jobs`, `/errors`, `/onlylogs`, `/railspress/admin`) are not system-tested, so their third-party markup is never audited. If you add a system test that visits one, give the audit an escape hatch rather than weakening the rule for the whole app.

## Console auditing

console1984 protects and audits the Rails console in production. Every console session and every command run inside it is recorded to the database (`console1984_sessions`, `console1984_commands` tables), and by default only the `production` environment is protected — development and test consoles are unrestricted. This requires Active Record encryption to be configured (see the Quickstart's credentials step above). If you want a web UI for browsing the audit trail, console1984's companion gem [`audits1984`](https://github.com/basecamp/audits1984) is not installed by default but can be added later.

## Superadmin access

Every developer-only panel — `/errors`, `/onlylogs`, `/admin/feedbacks`, the `/jobs` Solid Queue dashboard, the `/madmin` resource browser, the `/models` RubyLLM model list, `/railspress/admin` and the `/docs` documentation site — is gated by a single HTTP basic-auth credential pair, independent of the app's own session-based login, through the `SuperadminAuthentication` concern (`app/controllers/concerns/superadmin_authentication.rb`). A controller only needs `include SuperadminAuthentication`; the concern's `included` hook registers the `before_action`. Credentials resolve credentials-first then ENV, read live on every request (so tests can flip ENV per example):

- `Rails.application.credentials.dig(:superadmin, :username)` / `:password`, falling back to `ENV["SUPERADMIN_USER"]` / `ENV["SUPERADMIN_PASSWORD"]`

Comparison is constant-time (`ActiveSupport::SecurityUtils.secure_compare`). The gate is **deny-by-default**: when either value is blank, every request gets a `401 Unauthorized` — there is no "leave it open when unconfigured" fallback anywhere. This is deliberately stricter than the Solid Errors and onlylogs gem defaults, both of which leave their own dashboard open until a password is set; here that door is closed. Set the credentials block with `bin/rails credentials:edit`:

```yaml
superadmin:
  username: some-username
  password: some-password
```

To reuse one shared pair across every app born from this template, keep the values out of every repo and inject them at deploy time: store them once in your password manager, then list `SUPERADMIN_USER`/`SUPERADMIN_PASSWORD` under `env.secret` in `config/deploy.yml` and resolve them in `.kamal/secrets` (for example via `kamal secrets fetch --adapter 1password`, next to `RAILS_MASTER_KEY` and `OPENAI_API_KEY`). Rotating the credential is a redeploy — no repo ever contains the values.

### Background jobs (Mission Control)

`/jobs` is [Mission Control — Jobs](https://github.com/rails/mission_control-jobs), the dashboard for Solid Queue: browse queues, inspect and retry failed jobs, pause and resume queues. It's gated by the same superadmin auth — `config/initializers/mission_control_jobs.rb` sets `MissionControl::Jobs.base_controller_class = "MissionControlJobsBaseController"` (which just `include SuperadminAuthentication`) and `MissionControl::Jobs.http_basic_auth_enabled = false`, so the gem's own basic auth stands down and only the superadmin gate applies.

### Resource browser (madmin)

`/madmin` is a [madmin](https://github.com/excid3/madmin) panel for browsing and editing the app's records, gated by the same superadmin auth (`Madmin::ApplicationController` includes the concern). It ships dashboards for the domain models only — `Chat`, `Document`, `Feedback`, `Message`, `Model`, `Session`, `ToolCall`, `User`, plus `Noticed::Notification` and `Noticed::Event`. The framework-internal and sensitive resources the installer generates (Active Storage, Action Text, console1984 audit logs, and Solid Errors — which already has `/errors`) were removed from `config/routes/madmin.rb`, `app/madmin/resources/`, and `app/controllers/madmin/`. Adding a dashboard for a new model is a manual, deliberate step — there is no "auto-generate a dashboard for every model" option, in madmin or here. The resource generator reads the model's columns (`attribute_names`/`attribute_types`), so the table has to exist first; run it **after** the migration:

```bash
bin/rails g model Widget name:string
bin/rails db:migrate
bin/rails g madmin:resource Widget
```

Then trim the generated route/resource/controller the same way if the generator pulls in extras you don't want exposed. (This ordering is why a "create the model, get the dashboard for free" hook isn't wired: right after `rails g model` the table hasn't been migrated yet, so the resource generator would fail.)

Two integration points with the template's conventions: madmin's generated files are excluded from the 100%-coverage gate (`skip "app/madmin"` / `skip "app/controllers/madmin"` in `test/test_helper.rb`), since they're generated boilerplate; and `Madmin::ApplicationController` disables Bullet for the duration of each madmin request (`around_action :without_bullet if defined?(Bullet)`), because madmin's index views intentionally lazy-load associations and would otherwise trip the strict N+1 gate — acceptable for a dev-only panel over bounded data.

### Documentation site (/docs)

`/docs` serves this repo's own documentation from inside the running app: the two guides (`README.md` and `CLAUDE.md`) plus every page under `docs/architecture/`, rendered from Markdown by [Redcarpet](https://github.com/vmg/redcarpet) with a landing page, a sidebar, a per-page table of contents, a light/dark control and a ⌘K search that filters a client-side index. It's gated by the same superadmin basic auth as the other panels (`DocsController` includes the concern and keeps `allow_unauthenticated_access`), `robots.txt` disallows it, and its layout sends `noindex`. The `Dockerfile` already copies `docs/` into the image, so it works in production too.

`Doc` (`app/models/doc.rb`) is a plain object over those files. Its safety property is worth knowing: `Doc.find` resolves a slug by matching it against the list `Doc.all` returns, never by joining the parameter onto a root path — so `/docs` is a reader of a fixed set of pages, not an arbitrary file reader, and traversal is impossible by construction rather than by sanitizing the input. A slug that isn't listed is a `404`.

Two details that would be easy to get wrong: the heading anchors used by the table of contents come from Redcarpet's own `HTML_TOC` renderer rather than a hand-rolled slugifier, because both renderers compute the anchor with the same C function and anything else drifts; and the search index is embedded as a `<script type="application/json">` data island, because the CSP is nonce-based and strict for scripts — an inline script assigning the index to a variable would be blocked and the search would fail silently. See `docs/architecture/docs-site.md`.

## Blog & content (RailsPress)

The template ships a blog and lightweight CMS through the [`railspress-engine`](https://github.com/aviflombaum/railspress-engine) gem, mounted at `/railspress`. RailsPress owns the **back-office**: an admin UI at `/railspress/admin` for drafting, scheduling and publishing posts (with Lexxy rich text), categories, tags, optional authors, auto-generated slugs, per-post SEO (`meta_title`/`meta_description`), header images and galleries, plus custom Entities, CMS Blocks, and a JSON API. It does not ship any reader-facing pages.

The **public frontend is the template's own**, so it matches your app's look: `BlogController` (`app/controllers/blog_controller.rb`) serves `/blog` (a list of published posts, newest first, with optional `?category=<slug>` and `?tag=<slug>` filters) and `/blog/:slug` (a single post, rendering its Action Text content and setting SEO meta tags). The views live in `app/views/blog/`, are styled with DaisyUI, and their copy is internationalized like the rest of the app — restyle them per project. Drafts and unknown slugs return `404`.

### Who can reach the blog admin (and how to change it)

`/railspress/admin` is gated by the shared [superadmin](#superadmin-access) basic auth **as a safe default only**. Conceptually the blog admin is not a developer panel — the superadmin is the engineer who maintains the app, whereas the blog admin is for an application *content editor* (a real user of the app with a content role). The template gates it behind superadmin simply because it has no content-editor role yet (authorization is capability-only, decided per app) and because open self-registration means gating by a bare "is signed in" check would be unsafe.

Changing that is a one-file edit — `RailspressAdminAuth` is the seam. `config/initializers/railspress.rb` sets `config.admin_auth_concern = "RailspressAdminAuth"`, and today that concern is:

```ruby
module RailspressAdminAuth
  extend ActiveSupport::Concern

  include SuperadminAuthentication
end
```

To open the admin to a content-editor role instead, replace the include with your own authorization, e.g.:

```ruby
module RailspressAdminAuth
  extend ActiveSupport::Concern

  included do
    before_action :require_content_editor
  end

  private

  def require_content_editor
    redirect_to main_app.root_path, alert: "Not authorized." unless Current.user&.content_editor?
  end
end
```

Two integration notes: a narrow Bullet safelist in `config/environments/test.rb` covers `Railspress::Post => :taggings` (a `has_many :through` false positive — the join table is loaded to serve `.tags` but never accessed directly); and `superadmin_authentication.rb` and `railspress_admin_auth.rb` are excluded from the coverage gate (`skip` in `test/test_helper.rb`) because the RailsPress engine includes them into its admin controller at boot (`config.to_prepare`), which the parallel test runner's coverage can't attribute — their behavior is still verified by each superadmin panel's integration tests. (Also note: RailsPress 1.4.4 declares an `excerpt` field but ships no `excerpt` column, so `Railspress::Post#excerpt` doesn't exist.)

## Background jobs

Solid Queue runs **inside Puma** everywhere jobs are processed. `config/puma.rb` activates `plugin :solid_queue` when `SOLID_QUEUE_IN_PUMA` is set — which `config/deploy.yml` does in production — or when the environment is development, so both `bin/rails server` and `bin/dev` start the supervisor alongside the web server. `Procfile.dev` therefore has no `jobs:` line, and must not grow one: a second supervisor would run every job twice. `test/integration/development_processes_test.rb` guards both halves.

Development uses production's cable adapter for the same reason: `config/cable.yml` sets `solid_cable` in development, not `async`, so a broadcast from a job, a console or a request behaves identically in both. The `async` adapter only delivers within one process, so anything broadcast from elsewhere — a streamed chat reply, a Turbo Stream update — would silently never reach the browser. The same test asserts development and production agree on the adapter. The system suite cannot catch it, because system tests run jobs with the `:inline` adapter and always broadcast from the web process.

Note that Solid Queue logs to `log/development.log`, not to stdout, so your terminal stays quiet even while the supervisor works.

This requires the queue and cable tables to exist outside production, so `config/database.yml` gives **development and test** their own `queue` database (`storage/development_queue.sqlite3`, `storage/test_queue.sqlite3`, loaded from `db/queue_schema.rb`), and `config/environments/development.rb` and `test.rb` set `config.solid_queue.connects_to`. `bin/setup` and `bin/rails db:prepare` create both.

Development also sets `config.active_job.queue_adapter = :solid_queue`; **the test environment deliberately does not**. Tests keep Rails' `:test` adapter (and system tests use `:inline`), so the suite's job behaviour is unchanged — the queue database is there only so code that reads Solid Queue's own tables, like the health check, can be tested against real rows.

One consequence worth knowing while developing: jobs **persist across restarts**, which is faithful to production and occasionally surprising. And Solid Queue itself performs **no automatic retries** — its README is explicit that retrying is Active Job's job. A job that raises and declares no `retry_on` lands in `solid_queue_failed_executions` and stays there until someone retries or discards it from `/jobs` or a console; Solid Errors records the exception either way.

## Analytics

`ahoy_matey` ships as a **capability, not as instrumentation** — the same stance as noticed and pundit. The tables, the privacy configuration, the retention job and the wiring are all here; **zero events are tracked**, because what is worth measuring is a per-app product decision, not a template one.

### What it records

- `Ahoy::Visit` — one row per visit, created automatically on the server: referrer, referring domain, landing page, UTM parameters, browser, OS, device type, masked IP, and the user if one is signed in.
- `Ahoy::Event` — only what an app chooses to track, with arbitrary JSON properties.

Both live in the primary SQLite database and are ordinary Active Record models, so you query behaviour with the same tools you query everything else — including joins against your own tables, which is the whole point of first-party analytics.

### The recipe

Adding a measurement to a child app is three steps.

**1. Track it where it happens.** In any controller, `ahoy` is available:

```ruby
def create
  @document = Current.user.documents.create!(document_params)
  ahoy.track "Document created", document_id: @document.id
  redirect_to @document
end
```

Use a stable, human-readable name — it is the key you will query by forever, so `"Document created"` ages better than `"doc_create_v2"`. Properties should be identifiers and small scalars, not whole records.

**2. Query it.** No dashboard ships; the data is yours to ask questions of:

```ruby
Ahoy::Event.where(name: "Document created", time: 1.week.ago..).count
Ahoy::Event.where_event("Document created", document_id: 42)
Ahoy::Event.where(name: "Document created").group(:user_id).count
```

The queries worth writing are the ones a third-party tool cannot answer, because they join analytics to your domain: how many people who created a document in their first week still have an active session a month later, for instance.

**3. Decide retention.** `Ahoy::Visit::RETENTION` defaults to 90 days and a `purge_expired_visits` task in `config/recurring.yml` runs `Ahoy::Visit.purge_expired` nightly, deleting expired visits and their events in bulk. These are the fastest-growing tables in any app that uses them, and this is SQLite on a single volume — shorten the window rather than lengthen it.

To see the data in a UI, generate a madmin dashboard (`bin/rails g madmin:resource Ahoy::Visit`) and route it, following the pattern in "Resource browser".

### Privacy defaults

Configured in `config/initializers/ahoy.rb`, and chosen so the template does not contradict its own data-export and account-deletion promises:

- `Ahoy.cookies = :none` — no tracking cookie is set at all; visitors are grouped into anonymity sets instead. **This is what makes a cookie-consent banner unnecessary.**
- `Ahoy.mask_ips = true` — the last octet (IPv4) or last 80 bits (IPv6) is zeroed before storage.
- `Ahoy.geocode = false` — no location lookup, and the generated migration was trimmed of the `country`/`region`/`city`/`latitude`/`longitude` columns it would have filled, plus the native-app columns this template has no use for. Ahoy slices data to the columns that exist, so removing them is safe.
- `Ahoy.api = false` — tracking is **server-side only**. No JavaScript is loaded, no public `POST /ahoy/events` endpoint is exposed, and there is nothing extra for the Content Security Policy to allow. To add client-side tracking, set `Ahoy.api = true`, vendor the JS with `bin/importmap pin ahoy.js --download`, and `import "ahoy"` in `app/javascript/application.js` — it is same-origin, so the CSP still holds.
- Bots are excluded (`Ahoy.track_bots` defaults to false). This is why integration tests that do not send a browser `User-Agent` create no visits.

Behavioural data about a person is personal data, so `User` declares `has_many :ahoy_visits` and `has_many :ahoy_events` with `dependent: :destroy`. That single choice puts analytics inside **both** existing guarantees for free: `DataExport` walks `dependent: :destroy` associations, so a person's visits and events appear in their export, and deleting an account erases them.

### Two wiring details that would otherwise fail silently

Both are template-specific and neither raises an error when wrong — the data just comes out anonymous.

1. **`Ahoy.user_method` is overridden to `Current.user`.** Ahoy looks for a `current_user` method by default, which this app does not have. This is the same override as `pundit_user` in `ApplicationController`, and for the same reason.
2. **`ApplicationController` resolves the session eagerly.** Ahoy registers its `before_action` on `ActionController::Base`, so by default it runs *before* authentication and sees no user. `ApplicationController` therefore re-orders it (`skip_before_action :track_ahoy_visit` then `before_action :track_ahoy_visit`) and adds `before_action :resume_session` ahead of it. That second line matters more than it looks: this app resolves sessions lazily — on pages with `allow_unauthenticated_access`, without it `Current.session` would only be set when the layout calls `authenticated?` during rendering, after every `before_action` has run. Resolving it once, early, costs no extra queries (`Current.session ||=` memoises) and means anything that needs to know who is making a request — analytics, auditing, per-user rate limiting — can rely on it.

## Sitemap and robots.txt

Both are served dynamically by `SitemapsController` rather than sitting in `public/`, and the static `public/robots.txt` was deleted.

The reason is the `Sitemap:` directive: it requires an **absolute** URL, and a file checked into `public/` cannot know which host is serving it. A template that ships a static `robots.txt` either omits the directive or hardcodes a host that is wrong in every app born from it — the same footgun as `APP_HOST`. Rendering it from a controller means `sitemap_url` is always right, on any host, with nothing to remember.

`/sitemap.xml` lists the home page, the blog index, and every **published** RailsPress post with its `lastmod`; drafts are excluded, because `Railspress::Post.published` is the same scope the public blog uses. `/robots.txt` points crawlers at the sitemap and disallows the developer panels (`/admin`, `/errors`, `/jobs`, `/madmin`, `/onlylogs`, `/railspress`) — they are behind basic auth anyway, so this is hygiene rather than protection.

Nothing is cached. For a blog of a few hundred posts the query is trivial; if an app grows past that, add `fresh_when(@posts.maximum(:updated_at))` to the action rather than reaching for a generator gem.

## Health checks

Two endpoints, with deliberately different jobs.

`/up` is Rails' built-in liveness probe: 200 if the app boots and serves a request, 500 otherwise. **Kamal's proxy uses it** to gate deploys and to pull containers out of rotation, so it must stay shallow — make it strict and a momentarily lagging dependency will block a deploy or restart the container in a loop. Leave it alone.

`GET /health` is the deeper check, meant for an external uptime monitor. It is public (no session, no basic auth) and answers JSON:

```json
{ "status": "ok", "checks": { "database": "ok", "jobs": "ok" } }
```

It returns `200` when every check passes and `503` when any fails, with the failing check marked `"error"` — so a monitor only has to watch the status code. It is public because monitors are dumb: gating it behind the superadmin basic auth would work, but `SuperadminAuthentication` is deny-by-default, so a freshly cloned app with no credentials set would answer `401` and every monitor would read that as an outage. The information it discloses — whether the queue is alive — is not worth that. To gate it anyway, `include SuperadminAuthentication` in `HealthController` and give the monitor the credentials.

The checks live in `HealthCheck` (`app/models/health_check.rb`), which returns a `{ name => boolean }` hash; the controller only renders it. Add a check by adding a line to `HealthCheck#call`. Two ship today:

- **`database`** — a `SELECT 1` on the primary connection.
- **`jobs`** — that a Solid Queue supervisor has sent a heartbeat recently. "Recently" reuses `SolidQueue.process_alive_threshold`, the same window Solid Queue itself uses to decide a process is dead and prune it, rather than a number invented here.

The jobs check exists because of how this template deploys. `config/deploy.yml` sets `SOLID_QUEUE_IN_PUMA: true`, so the queue supervisor runs *inside* the Puma process. If it dies, Puma keeps serving, `/up` keeps answering 200, and everything that depends on background work stops silently: transactional email (`deliver_later`), document embeddings, streamed chat responses, data exports, and feedback tickets forwarded to GitHub. That is the failure `/health` is for.

The check is only included when the app actually runs Solid Queue (`ActiveJob::Base.queue_adapter` is the Solid Queue adapter). `config.solid_queue.connects_to` is set in `config/environments/production.rb` only, and the development/test database is a single SQLite file with no queue tables, so outside production there is no queue to be down and reporting one would be a lie. Locally `/health` answers `{ "status": "ok", "checks": { "database": "ok" } }`.

Two details of the jobs check are easy to get wrong:

- **The supervisor's `kind` is never plain `"Supervisor"`.** `SolidQueue::Supervisor#kind` returns `"Supervisor(#{mode})"`, so the row reads `Supervisor(fork)` or `Supervisor(async)` depending on how it was started (`bin/jobs` and the Puma plugin both default to `fork`). The check matches `kind LIKE 'Supervisor%'`. An exact match on `"Supervisor"` compiles, passes review, and silently reports the queue as dead forever.
- **Detection lags by up to `SolidQueue.process_alive_threshold`** (5 minutes by default). A supervisor that shuts down gracefully deregisters itself and the check goes red immediately; one that is killed abruptly leaves its row behind with a recent heartbeat, and the check stays green until that heartbeat goes stale. That is inherent to heartbeat checks — size your monitor's alert window accordingly.

Both paths are covered by `test/models/health_check_test.rb`, which registers a real `SolidQueue::Process` row: the development *and* test environments both have a `queue` database (see "Background jobs"), so the check is exercised against real rows rather than stubs.

## Error tracking

[Solid Errors](https://github.com/fractaledmind/solid_errors) captures uncaught exceptions through Rails' native error reporter (`Rails.error`) and stores them, deduplicated by fingerprint, in the primary SQLite database (`solid_errors`/`solid_errors_occurrences` tables, migrated alongside everything else — no separate database needed). Browse them at `/errors`.

The dashboard is behind the shared superadmin basic auth (see [Superadmin access](#superadmin-access)), not the gem's own: `config/initializers/solid_errors.rb` sets `SolidErrors.base_controller_class = "SolidErrorsBaseController"`, and that controller just `include SuperadminAuthentication`. So `/errors` is deny-by-default like the other panels — the initializer does not set `SolidErrors.username`/`password`, which leaves the gem's own password-gated filter inert. Only the notification email stays panel-specific, read once in the initializer from Rails credentials first and an environment variable second:

- `Rails.application.credentials.dig(:solid_errors, :email_to)`, falling back to `ENV["SOLID_ERRORS_EMAIL_TO"]`

Email notification is off unless `email_to` resolves to a value; when it does, Solid Errors emails that address (via the app's already-configured Action Mailer) every time a new error occurs.

### Error feed

`GET /error_feed` hands new errors to a watcher outside the app: occurrences above a `since` id, 100 per page, with `next_cursor` and `more`. It is off until a token is set (`error_feed_token` in credentials, or `ERROR_FEED_TOKEN`), answering `404`; the watcher sends it as `Authorization: Bearer <token>`. It returns only what the error says about itself and its route pattern, never params, cookies, headers, URLs or user data. See `docs/architecture/error-tracking.md`.

### Browser errors

Server-side exceptions are only half the picture: a Stimulus controller that throws, a failed fetch, a rejected promise — none of that reaches the server on its own. `app/javascript/error_reporting.js` listens for `error` and `unhandledrejection` on `window` and posts to `POST /javascript_errors`, which wraps the report in a `JavascriptError` (`app/errors/`) carrying the browser's stack as its backtrace and hands it to `Rails.error.report(handled: true)`. Solid Errors picks it up like any other exception, so browser and server failures land in the same `/errors` dashboard, deduplicated the same way. The occurrence context records the page URL, the user agent, and the signed-in user's id.

This is a public write endpoint, so it is fenced on both sides. The client caps itself at five reports per page load (a render loop that throws on every frame cannot flood the store), truncates the message to 1000 characters and the stack to 4000, and swallows its own fetch failures so a failing report can never trigger another one. The server rejects a blank message with `400`, rate-limits to 30 reports per minute, truncates the message again and keeps at most 20 backtrace lines.

Two things about it are easy to get wrong:

- **The CSRF token is sent when present, not required.** `csrf_meta_tags` renders nothing when `allow_forgery_protection` is off — which is the case in the test environment — so a client that refused to report without a token would silently drop every report there, and the wiring could never be tested. The client attaches the token if the meta tag exists and lets the **server** be the enforcement point, which is where it belongs.
- **An error thrown from `page.execute_script` is masked.** The browser treats CDP-executed scripts as cross-origin, so the `error` event arrives with the message `"Script error."` and a null `error` object. That is why `test/system/javascript_error_reporting_test.rb` dispatches a synthetic `ErrorEvent` instead of throwing: it exercises the listener, the payload, the request and the recording, without fighting a browser security rule. Real errors in this app are not masked, because the CSP forbids cross-origin scripts in the first place.

## Log viewer

[onlylogs](https://github.com/renuo/onlylogs) mounts a self-hosted web log viewer at `/onlylogs`: live-tail the log in the browser, grep it (with regular expressions — install [ripgrep](https://github.com/BurntSushi/ripgrep) on the server for fast searches), and download it. No external log service involved.

Production keeps logging to STDOUT exactly as before (`bin/kamal logs` is unchanged), but `config/environments/production.rb` now broadcasts every line to a second destination through `ActiveSupport::BroadcastLogger`: `storage/logs/production.log`, on the persistent storage volume that `config/deploy.yml` already mounts. That file is rotated by Ruby's own `Logger` (`ActiveSupport::TaggedLogging.logger(path, 5, 100.megabytes)`): when it reaches 100 MB it shifts to `production.log.0`, keeping at most five files total (`production.log` plus `.0`–`.3`), so the on-disk copy is hard-capped at ~500 MB and can never fill the volume.

The viewer's file whitelist (`config.log_file_patterns` in `config/initializers/onlylogs.rb`) is restricted to exactly that path — onlylogs automatically extends a `*.log` entry to its `*.log.N` rotation suffixes, so the dropdown lists the rotated set too, and nothing else on the server is reachable through the viewer. In development and test the environment's own `log/<env>.log` is additionally whitelisted so the viewer has something to show locally.

Access control for the HTTP side (the `/onlylogs` page and its download endpoint) is the shared superadmin basic auth (see [Superadmin access](#superadmin-access)), not the gem's built-in one. Onlylogs ships its own basic-auth (it answers 403 when unconfigured, reads ENV ahead of credentials, and only once at boot); this app bypasses it through the gem's documented custom-auth hook — `config.disable_basic_authentication` plus `config.parent_controller` pointing at `OnlylogsBaseController` (`app/controllers/onlylogs_base_controller.rb`), which just `include SuperadminAuthentication`. So `/onlylogs` is gated by `SUPERADMIN_USER`/`SUPERADMIN_PASSWORD` exactly like the other panels — deny-by-default, read live per request — while the gem's own auth no-ops under `disable_basic_authentication`.

**Basic auth protects the HTTP surface only.** The live tail streams over Action Cable, and by the gem's design `Onlylogs::LogsChannel` performs no basic-auth check of its own — the WebSocket's boundary is whatever the app's cable connection accepts, which here is *any signed-in user* (`app/channels/application_cable/connection.rb`), and this template ships open self-registration. The channel's protection is the file whitelist plus path encryption: a streamable path must decrypt via `Onlylogs::SecureFilePath` (keyed from `secret_key_base`) and re-pass the whitelist. Two consequences:

- The gem's blank-path fallback (`initialize_watcher` with no `file_path` streams `default_log_file_path` with **no decryption and no whitelist check**) would have let any signed-in user live-tail the production log without onlylogs credentials. This template neutralizes it by setting `config.default_log_file_path = ""` — a path that can never exist, so the channel's text-file check rejects the fallback before reading anything. Don't point `default_log_file_path` back at a real log file; a channel test (`test/channels/onlylogs_logs_channel_test.rb`) guards this.
- Residual risk that remains after that fix: encrypted path tokens are normally only rendered into pages behind `/onlylogs` basic auth, but the channel never checks onlylogs credentials — so a signed-in user who somehow holds a valid encrypted token for a whitelisted file (a leaked page source, a shared URL, an operator's copy-paste) can stream that file over the socket without basic auth. The tokens don't expire (`MessageEncryptor` without expiry), so treat rendered `/onlylogs` HTML as sensitive.

**Known upstream gap** worth patching in the gem (renuo/onlylogs): the channel has no `parent_controller`-style hook to inject app authentication into the WebSocket path, and the gem README's claim that streaming always requires a whitelisted, encrypted path is false for the blank-path branch of `LogsChannel#initialize_watcher`. Until that's fixed upstream, the two mitigations above are what stand between a signed-in user and the log stream.

This is stage 1 of a two-stage plan. Stage 2 — streaming logs from all apps to one central onlylogs server instead of hosting a viewer per app — is deliberately not built yet: onlylogs' server side (https://onlylogs.io) is still in beta and not yet publicly self-hostable. When it is, the per-app viewer can be replaced by (or complemented with) streaming to that single central instance.

## Development email preview

[letter_opener_web](https://github.com/fgrehm/letter_opener_web) catches every email the app sends in development and lists them in a browsable inbox at `/letter_opener`, instead of trying to reach a real SMTP server. This is where password-reset emails (`PasswordsMailer`) and Solid Errors notification emails land while developing locally.

The gem lives in the `development` group of the `Gemfile`, so it never loads in test or production; `config/routes.rb` also mounts it only `if Rails.env.development?`, and `config/environments/development.rb` sets `config.action_mailer.delivery_method = :letter_opener_web`. Test and production delivery are untouched here — `config/environments/test.rb` still uses `:test`, and production uses the SMTP scaffold described under [Configuration → Email](#email) (`delivery_method = :smtp`, driven by `APP_HOST` + `SMTP_*` or the `smtp/*` credentials).

## User feedback

Signed-in users can leave feedback (with optional screenshots) from the "Feedback" link in the navbar dropdown, at `/feedback`. Every submission is saved locally as a `Feedback` record (`belongs_to :user`, `has_many_attached :photos`) — that part always works, with no configuration needed.

On top of that, each feedback can optionally open a GitHub Issue labeled `feedback` in a repo you choose. This is best-effort: `CreateFeedbackIssueJob` runs after the `Feedback` is created and silently does nothing unless both of these are set:

```bash
GITHUB_ISSUES_TOKEN=github_pat_your-fine-grained-token
GITHUB_ISSUES_REPO=your-org/your-repo
```

To create the token: on GitHub, go to Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token. Scope it to the single repository you want issues created in, and grant it **Issues: Read and write** repository permission (nothing else is needed). Set both env vars in `.env` (see `.env.example`).

`GithubIssues` (`app/models/github_issues.rb`) is a small PORO wrapping `Net::HTTP` — no extra gem — that POSTs to `https://api.github.com/repos/#{repo}/issues` with the token as a bearer credential and the `X-GitHub-Api-Version: 2022-11-28` header GitHub's REST API expects. `GithubIssues.configured?` is `false` whenever either env var is blank, and `CreateFeedbackIssueJob` checks that before doing anything — so with neither var set, feedback is captured locally and nothing ever reaches GitHub. If GitHub responds with anything other than a 2xx, the client raises — and nothing retries it. Solid Queue has no automatic retry mechanism and this job declares no `retry_on`, so the failure lands in `solid_queue_failed_executions` and waits there to be retried or discarded from `/jobs` or a console; Solid Errors records the exception. The local `Feedback` row is already saved by then, so only the mirror to GitHub is lost.

Any photos attached to the feedback are linked in the issue body through a permanent public route, `/feedback/photos/:signed_id` (`FeedbackPhotosController`), rather than a raw Active Storage blob URL — those expire and GitHub can't authenticate to fetch them anyway. That controller resolves the signed ID to a blob and then checks the blob is actually attached to some `Feedback#photos` before redirecting to it, so it can't be turned into a generic "serve any blob by signed ID" proxy for attachments elsewhere in the app (avatars, message attachments, etc.).

Those photo links are absolute URLs, built with `Rails.application.config.action_mailer.default_url_options` (the same host config used for password-reset emails) since a background job has no request to infer a host from. `config/environments/production.rb` ships that as the placeholder `{ host: "example.com" }` — like the `YOUR_REGISTRY_USER`/`YOUR_SERVER_IP`/domain placeholders in `config/deploy.yml`, **this must be replaced with your app's real production host before deploying**, or photo links inside GitHub issues will silently point at `example.com` instead of your app.

A future extension worth considering: auto-capturing a screenshot of the page the user was on when they opened the feedback form (e.g., via a JS screenshot library posting a data URL alongside the form). Not built here — today photos are whatever the user manually attaches, and the support chat's context capture (below) only ever carries plain text (page URL, user agent, viewport), never a screenshot image.

## AI support assistant

Every signed-in page shows a floating "Support" button (bottom-right corner). It opens a chat panel backed by a dedicated support `Chat` (`support: true`, one per user, found-or-created by `SupportChatsController`). The assistant listens to the person's problem or suggestion, asks clarifying questions in plain language, and once it understands the issue, calls `CreateSupportTicketTool` (`app/tools/create_support_ticket_tool.rb`, a `RubyLLM::Tool`) to file it — this creates a `Feedback` record for that user, reusing the exact same pipeline as the manual feedback form above: it always saves locally, and opens a labeled GitHub Issue when `GITHUB_ISSUES_TOKEN`/`GITHUB_ISSUES_REPO` are set. The assistant needs `OPENAI_API_KEY` to work at all (like the rest of the AI chat); without it, the support button still opens the panel, but the assistant can't reply.

Every time the widget's panel is opened for the first time on a page, its Stimulus controller (`app/javascript/controllers/support_chat_controller.js`) captures three plain strings — the page URL, the browser's user agent, and the viewport size (e.g. `"1512x982"`) — and appends them as `context[...]` query params on the frame's request to `SupportChatsController#show`. The controller whitelists exactly those three keys, discards anything else, and truncates each value to 2 kilobytes before storing them as plain text in `ticket_context` (a JSON column on `Chat`, used only by support chats — never interpreted, never executed, just carried along as metadata). That column is deliberately **not** called `context`: RubyLLM's `acts_as_chat` already defines its own `context` attribute on chat records (for provider-specific request configuration), and reusing that name silently breaks it. When `CreateSupportTicketTool` files the ticket, it copies `chat.ticket_context` onto the new `Feedback#context` (a plain JSON column — no naming conflict there), and `CreateFeedbackIssueJob` renders those values as a `Context:` block inside the trusted, developer-only metadata section of the issue body, before the `---` separator that precedes the person's own words. None of this ever reaches the chat UI the person sees — it only ever surfaces in the GitHub issue.

The widget also has a small attach control (the paperclip icon, via `lucide_icon("paperclip")`) next to the message box. Picking a file uploads it immediately to `POST /support_chat/photos` (`SupportChatPhotosController`, scoped strictly through `Current.user.chats.find_by!(support: true)` — there is no way to attach to another user's chat), where it's held on `Chat#pending_photos` (`has_many_attached`, with the exact same content-type/size validation as `Feedback#photos`). When the ticket is filed, `CreateSupportTicketTool` attaches those same blobs onto the new `Feedback#photos` and then calls `chat.pending_photos.detach` — **not** `.purge`. `Blob#purge` does rescue `ActiveRecord::InvalidForeignKey`, so the `active_storage_attachments` → `active_storage_blobs` foreign key (present in this app's schema, with SQLite foreign keys on by default) would in practice stop a `purge` from deleting a blob still referenced by the `Feedback`'s new attachment. But relying on that rescue for correctness would be fragile — it depends on the FK constraint existing and being enforced, and it would still destroy the `Chat`'s own attachment row and briefly attempt (then abort) the delete. `.detach` sidesteps all of that: it only removes the join row and never touches the blob, so it's correct independent of any FK-constraint behavior. From there the photos flow into the GitHub issue exactly like manually-attached feedback photos do: through the public `/feedback/photos/:signed_id` route.

**The binding rule:** nothing the person sees in this chat may ever contain code, file names, stack traces, class names, or any other technical detail — only plain, human-friendly language. This is enforced in depth:

1. `SupportContext.instructions` (`app/models/support_context.rb`) prepends `SupportContext::BINDING_RULE`, a fixed English sentence stating the rule, to every support chat's system prompt. `SupportAgent` (`app/agents/support_agent.rb`, a `RubyLLM::Agent`) declares these instructions and the ticket-filing tool; `ChatResponseJob` finds the chat through `SupportAgent.find(chat_id)` instead of `Chat.find` only when `chat.support?` is true — normal chats are unaffected. Because `Agent.find` applies instructions at runtime (never persisted as a `messages` row), a multi-turn support conversation re-sends the same instructions on every turn without ever duplicating or staling a persisted system message.
2. `config/support_context.md` — a short, human-friendly, explicitly non-technical description of the app — is the *only* app-specific knowledge given to the assistant. It ships as a placeholder; **keep it non-technical when you edit it for your own app.** `SupportContext.content` reads it (empty string if the file is ever removed).
3. Technical message types (the system prompt itself, tool-call requests, tool results) are never rendered in the support chat's UI even if something goes wrong upstream: `Message#to_partial_path` renders those as a blank partial for support chats specifically (`app/models/message.rb`), while the normal chat UI (which is meant to be transparent/debuggable) still shows them in full.
4. The ticket itself — the refined title and summary the tool files — is written for the developer and can be as technical as the person's own words make it; only the chat reply shown back to the person stays in plain language.

## Ticket lifecycle

Every `Feedback` (whether filed through the manual form or the AI support assistant above) carries a `status` (`open`/`resolved`, default `open`) and a `resolved_at` timestamp. `Feedback#resolve!` sets both; calling it on an already-resolved ticket is a no-op — `resolved_at` doesn't change and it doesn't raise. Resolving a ticket only updates that local record; **it never sends any notification** (no email, no GitHub comment) — the scope here is ticket control, nothing more.

Open tickets are worked from a minimal admin panel at `/admin/feedbacks` (`Admin::FeedbacksController`): a table of open tickets with the reporter's email, message, context, links to any attached photos (reusing the same public `/feedback/photos/:signed_id` route the GitHub issue body uses), and a "Resolve" button per row that calls `resolve!` and redirects back. Resolved tickets drop off the list; there's no separate view for them, since ticket control — not a full archive — is the goal.

The panel sits behind the shared superadmin basic auth (see [Superadmin access](#superadmin-access)), independent of the app's session-based login: `Admin::FeedbacksController` `include SuperadminAuthentication` and keeps `allow_unauthenticated_access` so only the superadmin gate applies. Access is the same `SUPERADMIN_USER`/`SUPERADMIN_PASSWORD` (or `superadmin` credentials block) as every other panel — resolved live per request, deny-by-default, so `/admin/feedbacks` returns `401 Unauthorized` until the credentials are set. Configure them before you need the panel; there's no way to reach it otherwise.

## Money

[money-rails](https://github.com/RubyMoney/money-rails) is installed and configured with USD as the default currency (`config/initializers/money.rb`), but no monetized model ships with the template. To add a monetized column to a model: add `t.monetize :price` to a migration (this creates `price_cents` and `price_currency` columns), then declare `monetize :price_cents` on the model.

## Icons

The template's icon set is [Lucide](https://lucide.dev), via the `lucide-rails` gem: icons render as inline `<svg>` markup through the `lucide_icon` helper, no icon font and no CDN. In any view:

```erb
<%= lucide_icon "house", class: "size-4" %>
```

The first argument is the icon's name as it appears in the [Lucide icon library](https://lucide.dev/icons) (kebab-case, e.g. `house`, `arrow-right`, `circle-check`). Any keyword argument becomes an HTML attribute on the rendered `<svg>` — `class:` is the common case for sizing and color, since stroke color follows `currentColor` by default. Global defaults (applied to every icon) can be overridden via `LucideRails.default_options=` in an initializer if a future app needs that; the template doesn't set one.

## Notifications

[Noticed](https://github.com/excid3/noticed) provides the in-app notification pipeline: a bell in the navbar, a `/notifications` page, and the database tables and Active Job wiring underneath them. The template ships **zero notifications** — no notifier ever fires in app code. What ships is the capability: install the gem's migrations, `ApplicationNotifier` as a base class, the `User` recipient association, and the bell UI. A child app adds one notifier class and the bell works.

The installed gem is Noticed 3.0.0, which keeps the `Event`/`Notification` split introduced in the v2 rewrite (v1 used a single notification class). In this architecture, database persistence is core, not a delivery method — declaring `deliver_by :database` raises a deprecation warning and does nothing (`Noticed::Deliverable#deliver_by`, noticed gem, `app/models/concerns/noticed/deliverable.rb`). Calling `SomeNotifier.deliver(recipients)` always saves a `Noticed::Event` row (the thing that happened, with an optional polymorphic `record`) and one `Noticed::Notification` row per recipient (the per-person inbox entry: `read_at`, `seen_at`), inside a transaction — synchronously, no job needed just to see it in someone's inbox. Only the *delivery methods* you declare (`:email`, `:action_cable`, `:slack`, etc.) run through a background job (`Noticed::EventJob`, itself an `ActiveJob::Base` subclass), which Solid Queue is already configured to run in this app.

### Create a notifier

```bash
bin/rails generate noticed:notifier NewCommentNotifier
```

Or by hand, inheriting from `ApplicationNotifier` (`app/notifiers/application_notifier.rb`):

```ruby
# app/notifiers/new_comment_notifier.rb
class NewCommentNotifier < ApplicationNotifier
  notification_methods do
    def message
      "#{params[:comment].author.name} commented on your post"
    end

    def url
      post_path(params[:comment].post)
    end
  end
end
```

Deliver it to one or many recipients:

```ruby
NewCommentNotifier.with(record: comment, comment: comment).deliver(post.author)
```

`record:` is special — it fills the `Noticed::Event#record` polymorphic association (what the notification is *about*), so you can later ask "every notification generated from this comment." Any recipient with `has_many :notifications, as: :recipient, class_name: "Noticed::Notification"` (already added to `User`) picks it up immediately: `recipient.notifications.unread.count`, `recipient.notifications.newest_first`, `notification.mark_as_read`. The bell (`app/views/shared/_notification_bell.html.erb`, backed by `NotificationsHelper`) and the full list at `/notifications` (`NotificationsController`, scoped through `Current.user`) render whatever `message` your notifier's `notification_methods` block defines — every notifier you write needs one.

`User#notifications`'s `dependent: :destroy` only cleans up the recipient side: if you pass `record:` and that record is later destroyed, its `Noticed::Event` rows (and their notifications) are not cleaned up automatically and will linger in `noticed_events`. If you add a notifier tied to a record, also add the record-side association Noticed's own README documents ("Associating Notifications"): `has_many :noticed_events, as: :record, dependent: :destroy, class_name: "Noticed::Event"` on that model.

### Email opt-in pattern

Nothing ships with email enabled. To add it to a specific notifier, use Noticed's built-in `:email` delivery method and guard it with `config.if`:

```ruby
class NewCommentNotifier < ApplicationNotifier
  deliver_by :email do |config|
    config.mailer = "NewCommentMailer"
    config.method = :notify
    config.if = -> { recipient.email_notifications? }
  end

  notification_methods do
    def message
      "#{params[:comment].author.name} commented on your post"
    end
  end
end
```

`config.mailer` and `config.method` are required (`Noticed::DeliveryMethods::Email`, noticed gem, `lib/noticed/delivery_methods/email.rb`); the delivery method calls `mailer.with(params).public_send(method)`, so the mailer action reads `params[:notification]`, `params[:record]`, and `params[:recipient]`. `config.if`/`config.unless` are evaluated per-recipient at delivery time (not at `.deliver` time), so you can check a per-user preference, not just a global switch. This exact pattern — a `deliver_by :email` block guarded by `config.if`, backed by a plain `ActionMailer::Base` mailer — is exercised end-to-end by the template's only notifier, `TestNotifier` (`test/notifiers/`), which is test-only and never invoked by app code. Its test (`test/notifiers/test_notifier_test.rb`) delivers with and without the opt-in param and asserts `ActionMailer::Base.deliveries` accordingly.

In development, any email a notifier sends lands in the same [letter_opener](#development-email-preview) inbox at `/letter_opener` as password resets — no separate setup needed.

### Future channels (not installed)

- **Web push** (desktop/mobile browser notifications while the app is closed) needs the [`web-push`](https://github.com/pushpad/web-push) gem plus VAPID keys and a service worker subscription flow. Deliberately not installed — add it if a real notifier needs it, then `deliver_by :web_push` following Noticed's docs.
- **Mobile push** (iOS/Android native apps) is supported by Noticed's built-in `:fcm` (Firebase Cloud Messaging) and `:ios` (Apple Push Notification Service) delivery methods — no extra gem needed, just credentials and device tokens, wired up the same `deliver_by` way as `:email` above.

## Authorization

[Pundit](https://github.com/varvet/pundit) provides the authorization capability: plain Ruby policy classes that answer "may this user do this to this record." The template ships **zero policies** — no `authorize` call exists in app code, mirroring how [Notifications](#notifications) ships zero notifiers. What ships is the capability: the gem, `Pundit::Authorization` included in `ApplicationController` (with `pundit_user` mapped to `Current.user`, since this app has no `current_user`), a `rescue_from Pundit::NotAuthorizedError` that redirects back with an alert, and `ApplicationPolicy` (`app/policies/application_policy.rb`) as the default-deny base class. A child app adds one policy class and authorization works.

Until you need it, `Current.user` scoping **is** the template's authorization: every controller already fetches records through `Current.user.chats`, `Current.user.documents`, and so on, which makes "not yours" indistinguishable from "not found." Reach for Pundit when that stops being enough — the first role (admin, moderator), the first shared resource (a document with viewers and editors), the first rule beyond "the owner may do everything."

### Create a policy

```bash
bin/rails generate pundit:policy Document
```

Or by hand, inheriting from `ApplicationPolicy`:

```ruby
# app/policies/document_policy.rb
class DocumentPolicy < ApplicationPolicy
  def show?
    record.user == user
  end

  def update?
    record.user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
```

`ApplicationPolicy` answers `false` to every action, so a policy only grants what it explicitly opens up. In a controller, `authorize` looks up the policy from the record's class, asks the query named after the current action (`authorize document` inside `update` asks `DocumentPolicy#update?` — the query defaults to `"#{action_name}?"`), returns the record when allowed, and raises `Pundit::NotAuthorizedError` when not — which the `ApplicationController` rescue turns into a redirect back (or to root) with an alert toast:

```ruby
def update
  @document = Document.find(params[:id])
  authorize @document
  @document.update!(document_params)
end
```

For index-style actions, `policy_scope(Document)` runs your policy's `Scope#resolve` against the current user and returns the filtered relation. In views, the `policy` helper drives conditional UI: `<% if policy(document).update? %>` around the edit link.

The whole pipeline — permit, deny with the redirect-and-alert rescue, and scope filtering — is exercised by the template's test-only `PunditTestRecordPolicy` (`test/policies/`), a policy for a plain test-only record class that shadows no app model, never loaded by app code, exactly like `TestNotifier`.

### Opt-in strictness

Once an app adopts policies broadly, Pundit can enforce that no action forgets them: `after_action :verify_authorized` raises unless the action called `authorize` (and `after_action :verify_policy_scoped` does the same for `policy_scope` on index actions). The template deliberately does not enable these — they would force a policy onto every existing action, and that is an app decision, not a template one. When you flip them on, `skip_authorization` / `skip_policy_scope` mark the actions that legitimately have nothing to authorize.

## Deployment

Deploys use [Kamal](https://kamal-deploy.org). Before your first deploy, edit `config/deploy.yml` and replace every UPPERCASE placeholder with real values:

- `YOUR_REGISTRY_USER` — your container registry username
- `YOUR_SERVER_IP` — your server's IP address
- `app.YOUR_DOMAIN.com` — the domain the app will be served from

`RAILS_MASTER_KEY` and `OPENAI_API_KEY` are injected as secrets via `.kamal/secrets` (which reads `config/master.key` and the `OPENAI_API_KEY` environment variable — never commit real secrets into that file). A persistent storage volume (`storage/` mounted at `/rails/storage`) is mandatory: it holds the SQLite database files and any locally-stored Active Storage uploads, so losing it means losing data.

The `env:` block also declares `APP_HOST` (clear) plus `SUPERADMIN_USER`, `SUPERADMIN_PASSWORD`, `ERROR_FEED_TOKEN`, `SMTP_USER_NAME`, and `SMTP_PASSWORD` (secret) — a first deploy must set the real domain in `config/deploy.yml` and uncomment those five in `.kamal/secrets`, or mailer links point at `example.com`, no email sends, every developer panel answers `401`, and no watcher can read the app's errors.

```bash
kamal setup
```

## Backups

Everything lives on that one `storage/` volume — the four SQLite databases (primary plus Solid Queue/Cache/Cable) and the Active Storage uploads — so a lost volume means lost data. The template ships a backup story for exactly that: [kamal-backup](https://github.com/crmne/kamal-backup) (by the author of RubyLLM), wired as a Kamal accessory that takes encrypted, deduplicated, scheduled [restic](https://restic.net) snapshots to any restic/rclone remote (S3, Backblaze B2, SFTP, …). It backs up the four SQLite databases *consistently* (not raw file copies) and the Active Storage files on the volume in one pass — `config/kamal-backup.yml` lists the databases and a `paths: [/rails/storage]` entry for the uploads, and kamal-backup automatically excludes the raw db/WAL/shm files it already snapshots as databases.

Unlike the commented `mysql`/`redis` examples, the `backup` accessory in `config/deploy.yml` is **active by default** — backups are treated as first-class here. Because it's active, it won't boot until you configure it, which is deliberate: it forces the decision before real data exists. To enable it:

- In `config/kamal-backup.yml`, set `restic.repository` (replace `YOUR_RESTIC_REPOSITORY`) and, if you want a smaller data-loss window, tighten `backup.schedule` (default `1d`, e.g. `1h`).
- In `.kamal/secrets`, uncomment and supply `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` (pulled from your password manager / ENV, never committed).

Inspect and restore with `bundle exec kamal-backup backup` / `list` / `evidence`; restore drills recover into scratch targets without touching live data.

## Security headers

A [Content Security Policy](https://guides.rubyonrails.org/security.html#content-security-policy-header) is active (`config/initializers/content_security_policy.rb`) — the Rails initializer, normally shipped commented out, is turned on and configured. Everything loads from the app's own origin (`default-src 'self'`), with `object-src 'none'` and `frame-ancestors 'self'` for clickjacking protection, `img-src` widened to `data:`/`blob:`/`https:` for Active Storage and blog/user content, and `connect-src 'self'` covering the same-origin WebSocket behind Turbo Streams.

The posture is **strict scripts, inline styles allowed**: `script-src` is `'self'` plus a fresh per-request nonce (scripts are the real XSS vector), while `style-src` keeps `'unsafe-inline'` because Lexxy (the rich-text editor) and Turbo inject inline styles at runtime that can't carry a nonce. The nonce uses `SecureRandom` rather than the session id, so public, logged-out pages (sign-in, `/blog`) still get one without a session being created just for the header; `javascript_importmap_tags` and the layout's `csp_meta_tag` carry the nonce through, so importmap, Turbo, and Stimulus keep working. It's verified by the browser system tests (a broken CSP would stop the front end from booting and fail them) and a guard test at `test/integration/content_security_policy_test.rb`.

One caveat: the policy is applied globally, so it also covers the mounted admin engine UIs (`/madmin`, `/railspress/admin`, `/jobs`, `/errors`, `/onlylogs`). Those are behind the superadmin gate and aren't exercised by the system tests, so their JavaScript isn't validated under the CSP — if a panel's scripts break, relax the policy for that path or add nonces.

## Adding 2FA later

Two-factor authentication is not included, but the native authentication controllers this template ships with (`SessionsController`, `RegistrationsController`) are yours to extend. A minimal approach with [`rotp`](https://github.com/mdp/rotp):

```ruby
# add otp_secret + otp_required_for_login columns to users, then in SessionsController#create:
if user.otp_required_for_login
  return redirect_to new_session_otp_path(user_id: user.id) # a small controller that verifies ROTP::TOTP.new(user.otp_secret).verify(params[:code])
end
```

Wire the verification step in before `start_new_session_for(user)` is called, so a correct password alone never finishes authentication for an account with 2FA enabled.

## Updating this template

Since this repo doubles as a living app, keeping it current means:

1. Bump `.ruby-version` and the `rails` constraint in the `Gemfile`, then `bundle update rails`.
2. Re-download the vendored DaisyUI files (`app/assets/tailwind/daisyui.mjs`, `app/assets/tailwind/daisyui-theme.mjs`) from the DaisyUI release you're targeting.
3. Run any `ruby_llm:upgrade_to_*` generators RubyLLM ships when you bump its version, to pick up new migrations/config.
4. Run `bin/ci` before committing the upgrade.

Also worth re-checking after a Rails upgrade: whether Lexxy still needs to monkey-patch `rich_text_area` (see `CLAUDE.md`'s Subsystem map) — a new Rails version may ship the official `ActionText::Editor` adapter API Lexxy prefers.

## Porting template improvements into an existing app

Apps born from this template do not receive updates automatically — "Use this template" creates a fresh history with no git link back, and `bin/rename` rewrites the app's identity throughout the tree, so wholesale merges from the template would conflict everywhere the rename touched. This is a deliberate trade-off: your app fully owns its code and its name.

Individual improvements port well with cherry-pick:

```bash
git fetch https://github.com/bruno-costanzo/rails-template main
git log FETCH_HEAD --oneline
git cherry-pick <sha>
```

Fetch it on demand rather than adding a permanent remote: `bin/rename` removes the template remote precisely so an app cannot push into the template it came from, and a URL you fetch once carries no such risk.

What applies cleanly: commits that never mention the app name — JavaScript fixes, jobs, POROs, migrations, test helpers, gem bumps. Recent examples of this kind: streaming-race fixes, upload validations, N+1 guards.

What conflicts: anything `bin/rename` rewrote — layouts and views carrying the app name, `config/` files, `database.yml`, `deploy.yml`. For those, read the template commit's diff (`git show <sha>`) and apply the change by hand under your app's names.

Pick commits one at a time, run `bin/ci` after each, and skip anything your app has since diverged from — a template improvement is an offer, not an obligation.

The template side of this pairing lives in its own `children.yml`: `bin/spawn` registers every app it creates there, and `bin/children` reports which of them have pending commits, one at a time — the ready-made `cherry-pick` command always targets the OLDEST pending commit, so applying it and running the `bin/children synced <name> <sha>` line right after advances the sync pointer by exactly that one commit, never skipping the rest. Run the report again to get the next one. Both commands run **only from the template's own checkout**, never from an app born of it: `bin/rename` deletes `bin/spawn`, `bin/children` and `children.yml` the moment it turns the template into an app, so a child app cannot run this side of the workflow itself — only the template maintainer, from the template repo, can.
