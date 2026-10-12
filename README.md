# CharcoTemplate

## What is this

CharcoTemplate is a Rails 8.1.3.1 starter template. It is a fully working app on its own, and it is also the seed you clone to start a new project (`bin/rename <new_app_name>` rewrites the app's name throughout the codebase). Everything described below already exists in this repo — clone it, rename it, and build on top.

## Features

- Rails authentication with sign-up, email confirmation, profile, active sessions, account deletion and a ZIP data export
- AI chat (RubyLLM + OpenAI) with streaming replies, and documents with rich text and semantic search
- A floating AI support assistant and a feedback form, both filing tickets that can mirror to GitHub Issues
- A blog: RailsPress back-office at `/railspress/admin`, public pages at `/blog`
- Solid Queue, Solid Cache and Solid Cable on SQLite — no Redis
- Developer panels behind one password: records, jobs, errors, logs, tickets, docs
- Spanish and English UI, chosen from the browser's language
- Native iOS and Android apps driven from the views (`charco_mobile`)
- Tailwind v4 + DaisyUI 5 and Hotwire, with no Node
- Kamal deploy with encrypted backups

The detail of every subsystem lives in [`docs/architecture/`](docs/architecture/), also served by the app at `/docs`.

## Requirements

- [mise](https://mise.jdx.dev), or another way to install Ruby 4.0.6 (`.ruby-version`)
- libvips, for avatar variants
- An OpenAI API key, for the AI chat, semantic search and support assistant

In a shell without mise shims, run every Ruby command as `mise exec ruby@4.0.6 -- <command>`. The examples below show bare commands.

## Quickstart

```bash
git clone <this-repo> my_app
cd my_app
bundle install
bin/rename my_app
bin/setup
```

`bin/rename` rewrites the app's name in every file git tracks (every file, when the tree has no `.git`). Then it **removes the tooling that only serves the template**: itself, `bin/smoke-rename`, `bin/spawn`, `bin/children`, `children.yml`, `lib/template/`, their tests, the smoke step in `config/ci.rb`, the planning documents in `docs/superpowers/`, and the template-only parts of this README and `CLAUDE.md`. If the renamer's tests stayed, renaming would rewrite their fixtures into nonsense and the app would be born with a red `bin/ci`.

The name must become a Ruby module: letters, digits and single underscores, starting with a letter (`my_app`, `my-app` and `MyApp` all work). `bin/rename` refuses any other name before it touches a file.

A new app needs its own credentials. `config/master.key` never travels with the repo, and console1984 needs Active Record encryption keys inside the credentials:

```bash
rm config/credentials.yml.enc
bin/rails credentials:edit      # new master.key and secret_key_base
bin/rails db:encryption:init    # prints three keys
```

Copy the three printed keys into an `active_record_encryption:` block with `bin/rails credentials:edit`, then start the app:

```bash
bin/dev
```

`bin/dev` runs the Rails server and the Tailwind watcher (`Procfile.dev`). The job supervisor runs inside Puma and logs to `log/development.log`, not to your terminal.

A fresh clone signs in with `dev@example.com` / `password`. `db:prepare` seeds only when it creates the database, so on an existing checkout run `bin/rails db:seed`; the same seed loads the AI model registry that chat and search need.

## Starting a new app

The order to do things in, and the things nobody else can do for you.

**Before you write code**

1. From this template's own directory: `bin/spawn my_app [--github]`. It clones the template into `../my_app`, runs `bin/rename` there, removes the clone's `origin` remote (the new app must never push into the template), commits the rename, and registers the app in `children.yml` for later cherry-picks. It refuses any name `bin/rename` refuses, and a failure before registration removes `../my_app`, so you can fix the cause and re-run. `--github` also creates and pushes a private repo and sets its `CHARCO_MOBILE_DEPLOY_KEY` secret from the key file at `CHARCO_MOBILE_DEPLOY_KEY_PATH` (or prints the command when that is unset); without the flag it prints the `gh repo create` command for later. Then, inside `../my_app`: `bin/setup`, and regenerate the credentials and encryption keys as in [Quickstart](#quickstart).
2. **If you skipped `--github`, give the app its own repository now.** Commits pile up fast, and a clean `git log` looks the same whether or not it exists anywhere but your disk. To port a template improvement later you do not need a permanent remote:

   ```bash
   git fetch https://github.com/bruno-costanzo/rails-template main
   git cherry-pick <sha>
   ```

   Cherry-pick rather than copy files: where both repos changed the same file — `config/routes.rb`, the locale files, `db/schema.rb` — git stops and asks instead of overwriting your work.
3. Put `OPENAI_API_KEY` in `.env` if the app uses the AI chat, semantic search or support assistant — see [Configuration](#configuration).
4. **Delete what this app will not use.** The template ships a blog, an AI chat, documents with semantic search and a support assistant. Whatever you remove, remove from the screen list in `docs/design-substrate.md` too.
5. **Design system.** Connect *this app's* pruned repo to your design tool, paste `docs/design-substrate.md` unchanged, and fill in `docs/brand-brief-template.md`. What comes back is a DaisyUI theme block for `app/assets/tailwind/application.css`. Every system test audits contrast in both colour schemes, so the theme must pass WCAG AA — see [design](docs/architecture/design.md).
6. **Decide what is worth measuring** and add the events — see [analytics](docs/architecture/analytics.md). The template ships the plumbing and zero events.

**Before you deploy**

7. `APP_HOST` and the SMTP secrets — see [email](docs/architecture/email.md). Without them every mailer link and feedback photo link points at `example.com`.
8. `SUPERADMIN_USER` and `SUPERADMIN_PASSWORD` — see [superadmin panels](docs/architecture/superadmin-panels.md). Until they are set, every developer panel answers `401`.
9. Replace the `YOUR_*` placeholders in `config/deploy.yml` — see [Deployment](#deployment).
10. Set `restic.repository` in `config/kamal-backup.yml` and uncomment the backup secrets in `.kamal/secrets` — see [backups](docs/architecture/backups.md). **The backup accessory is active, so the deploy fails until you do this.** That is deliberate: decide about backups before there is real data to lose.

**After you deploy**

11. Point an uptime monitor at `https://your-app/health` — see [health checks](docs/architecture/health-checks.md). The endpoint reports on the database and the job supervisor, but nothing watches it until you wire a monitor up.
12. Set `ERROR_FEED_TOKEN` and give the same token to your error watcher — see [error tracking](docs/architecture/error-tracking.md). Until then nothing outside the app can read its errors.

## Configuration

```bash
cp .env.example .env
```

`.env` is gitignored; `.env.example` documents every variable. Each secret below can also live in Rails credentials, which are read first.

| Variable | What it does | Without it |
| --- | --- | --- |
| `OPENAI_API_KEY` | AI chat, semantic search, support assistant | Those features cannot answer |
| `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL` | Override `gpt-4o-mini` / `text-embedding-3-small`. A new embedding model needs a migration | Defaults apply |
| `APP_HOST` | Host for mailer and feedback photo links | Links point at `example.com` |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USER_NAME`, `SMTP_PASSWORD` | Production email, any provider (credentials: `smtp/user_name`, `smtp/password`) | No email is sent |
| `SUPERADMIN_USER`, `SUPERADMIN_PASSWORD` | One login for every developer panel (credentials: `superadmin/username`, `superadmin/password`) | Every panel answers `401` |
| `ERROR_FEED_TOKEN` | Bearer token for `/error_feed` (credentials: `error_feed_token`) | `/error_feed` answers `404` |
| `SOLID_ERRORS_EMAIL_TO` | Email on each new error (credentials: `solid_errors/email_to`) | No error email |
| `GITHUB_ISSUES_TOKEN`, `GITHUB_ISSUES_REPO` | Mirror feedback to GitHub Issues | Feedback is saved locally only |
| `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Backups (Kamal secrets, not app ENV) | The backup accessory does not boot |
| `CHARCO_MOBILE_DEPLOY_KEY` | GitHub Actions secret to fetch the private `charco_mobile` gem | CI fails at `bundle install` |

## Developer panels

All behind the one superadmin login, except where noted.

| Path | What |
| --- | --- |
| `/madmin` | Browse and edit records |
| `/jobs` | Solid Queue dashboard (Mission Control) |
| `/errors` | Server and browser errors (Solid Errors) |
| `/onlylogs` | Live production log |
| `/admin/feedbacks` | Open tickets, with a Resolve button |
| `/models` | The AI models RubyLLM knows |
| `/railspress/admin` | Blog back-office |
| `/docs` | This README, `CLAUDE.md` and `docs/architecture/` |
| `/letter_opener` | Sent email, development only, no login |
| `/health`, `/up` | Public health checks |

## Mobile apps

The views drive native iOS and Android shells through `config/charco_mobile.yml` and `native_*` helpers. To preview on a phone, run `bin/rails server` and `bundle exec charco_mobile preview` in two terminals and scan the QR code. See [mobile](docs/architecture/mobile.md).

## Testing

Run `bin/ci` before every commit. It is exactly what CI runs, configured in `config/ci.rb`: rubocop, brakeman, `bin/bundler-audit`, `i18n-tasks health`, `charco_mobile check`, `herb analyze`, `bin/rails test`, `bin/rails test:system`, and a `bin/smoke-rename` step.

Tests never hit the network. Coverage must stay at 100% lines and branches; N+1 queries and accessibility violations fail the build. While running a subset, set `SKIP_COVERAGE=1`. See [testing](docs/architecture/testing.md).

The smoke step tests the template's core promise: clone, rename, and get an app that boots and serves. It exports the tracked tree to a temp dir, runs `bin/rename smoke_app`, asserts no reference to the old name survives, runs `db:prepare` and `zeitwerk:check`, runs the copy's own test suite, then starts a real server and requests `/`, `/session/new`, `/registration/new`, `/blog`, `/sitemap.xml`, `/robots.txt` and `/health` (a healthy database; `jobs` is down there because no supervisor runs). Each check catches something the others miss: a leftover constant, a broken route or view, a test that renaming turned into nonsense.

The smoke reuses the existing bundle, so it costs a few seconds; `db:prepare` runs in the background while the boot check and the suite run. It needs no master key — a local `config/master.key` is copied in as a safety belt, and CI passes without one. It exports tracked files only, so `git add` a new file first. Because the local Bundler override lives in the gitignored `.bundle/config`, the export resolves `charco_mobile` from git, at a revision your own tree never materializes; after bumping the gem, a `bundle install` in a throwaway export, or the smoke alone, fails. Set `SMOKE_PORT` if port 3987 is taken.

## Subsystems

One page each in `docs/architecture/`:

- Accounts: [auth](docs/architecture/auth.md) (confirmation, sessions, deletion, 2FA path), [data export](docs/architecture/data-export.md), [email](docs/architecture/email.md)
- AI: [chat](docs/architecture/ai-chat.md), [semantic search](docs/architecture/semantic-search.md), [support assistant](docs/architecture/support-chat.md)
- Feedback: [user feedback](docs/architecture/user-feedback.md), [ticket lifecycle](docs/architecture/ticket-lifecycle.md)
- Content: [blog](docs/architecture/blog.md), [rich text](docs/architecture/rich-text.md), [sitemap and robots](docs/architecture/sitemap-robots.md), [i18n](docs/architecture/i18n.md), [pagination](docs/architecture/pagination.md)
- Capabilities shipped unused: [notifications](docs/architecture/notifications.md), [authorization](docs/architecture/authorization.md), [analytics](docs/architecture/analytics.md), [money](docs/architecture/money.md)
- Operations: [superadmin panels](docs/architecture/superadmin-panels.md), [background jobs](docs/architecture/background-jobs.md), [health checks](docs/architecture/health-checks.md), [error tracking](docs/architecture/error-tracking.md), [browser errors](docs/architecture/browser-errors.md), [log viewer](docs/architecture/log-viewer.md), [console auditing](docs/architecture/console-auditing.md)
- Front end: [design and icons](docs/architecture/design.md), [templates](docs/architecture/templates.md), [security headers](docs/architecture/security-headers.md), [mobile](docs/architecture/mobile.md)
- Shipping: [deploy](docs/architecture/deploy.md), [backups](docs/architecture/backups.md), [testing](docs/architecture/testing.md), [conventions](docs/architecture/conventions.md)

## Deployment

Deploys use [Kamal](https://kamal-deploy.org). In `config/deploy.yml`, replace `YOUR_REGISTRY_USER`, `YOUR_SERVER_IP` and `app.YOUR_DOMAIN.com`. In `.kamal/secrets`, uncomment the secrets the app needs (see [Configuration](#configuration)); never commit real values there. The `storage/` volume is mandatory: it holds the SQLite databases and the uploads.

```bash
kamal setup
```

Backups are [kamal-backup](https://github.com/crmne/kamal-backup) restic snapshots of the databases and uploads, to any S3, B2 or SFTP remote. Inspect and restore with `bundle exec kamal-backup backup`, `list` and `evidence`. See [deploy](docs/architecture/deploy.md) and [backups](docs/architecture/backups.md).

## Updating this template

Since this repo doubles as a living app, keeping it current means:

1. Bump `.ruby-version` and the `rails` constraint in the `Gemfile`, then `bundle update rails`.
2. Re-download the vendored DaisyUI files (`app/assets/tailwind/daisyui.mjs`, `app/assets/tailwind/daisyui-theme.mjs`) from the DaisyUI release you're targeting.
3. Run the `ruby_llm:upgrade` generator RubyLLM ships when you bump its version, to pick up new migrations/config. Its migrations can need the gem version that generated them; check that a fresh `bin/rails db:migrate` still runs.
4. Run `bin/ci` before committing the upgrade.

Also worth re-checking after a Rails upgrade: whether Lexxy still needs to monkey-patch `rich_text_area` (see `CLAUDE.md`'s Subsystem map) — a new Rails version may ship the official `ActionText::Editor` adapter API Lexxy prefers.

## Porting template improvements into an existing app

Apps born from this template do not receive updates automatically. "Use this template" creates a fresh history with no git link back, and `bin/rename` rewrites the app's identity throughout the tree, so a wholesale merge would conflict everywhere the rename touched. This is deliberate: your app fully owns its code and its name.

Individual improvements port well with cherry-pick:

```bash
git fetch https://github.com/bruno-costanzo/rails-template main
git log FETCH_HEAD --oneline
git cherry-pick <sha>
```

Fetch on demand rather than adding a permanent remote: `bin/rename` removes the template remote so an app cannot push into the template it came from, and a URL you fetch once carries no such risk.

What applies cleanly: commits that never mention the app name — JavaScript fixes, jobs, POROs, migrations, test helpers, gem bumps. What conflicts: anything `bin/rename` rewrote — layouts and views with the app name, `config/` files, `database.yml`, `deploy.yml`. For those, read the diff (`git show <sha>`) and apply it by hand. Pick commits one at a time, run `bin/ci` after each, and skip what your app has diverged from — a template improvement is an offer, not an obligation.

The template side of this pairing is `children.yml`: `bin/spawn` registers every app it creates, and `bin/children` reports which have pending commits. Its ready-made `cherry-pick` command always targets the OLDEST pending commit, so applying it and then running the printed `bin/children synced <name> <sha>` line advances the sync pointer by exactly one commit. Run the report again for the next one. A child whose recorded sync point the template no longer has (after a history rewrite) shows `unknown sync point`; point it at a commit the template has with `bin/children synced <name> <sha>`. Both commands run **only from the template's own checkout**: `bin/rename` deletes them from every app it creates.
