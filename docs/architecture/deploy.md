# Deploy

Kamal, configured in `config/deploy.yml`. Every value an app must replace is an UPPERCASE placeholder: the registry user, the server address, the host. `kamal setup` is the first deploy.

`.kamal/secrets` injects `RAILS_MASTER_KEY` from the gitignored master key and `OPENAI_API_KEY` from the environment; real values are never written into it. The `env` block also declares `APP_HOST` in clear and `SUPERADMIN_USER`, `SUPERADMIN_PASSWORD`, `ERROR_FEED_TOKEN`, `SMTP_USER_NAME` and `SMTP_PASSWORD` as secrets, which ship commented out in `.kamal/secrets`. A first deploy that leaves them out sends mailer links to `example.com`, sends no email, answers `401` on every developer panel and lets no watcher read the errors.

The `storage/` volume is mandatory, not an optimization. SQLite databases and locally-stored Active Storage files both live there, so a deploy without it loses the entire database on the next container rotation.

`SOLID_QUEUE_IN_PUMA` is set here, which is what makes the job supervisor run inside the web container (see background-jobs.md), and the backup accessory is active by default (see backups.md).

The image build reads `charco_mobile`, a private repository, with a read-only token: `Dockerfile` mounts `BUNDLE_GITHUB__COM` as a build secret on the `bundle install` layer and `config/deploy.yml` passes it under `builder`, so the token never lands in a layer. A build without it resolves every other gem and then fails on that one.

The runtime image installs the `file` command. Every photo upload (avatar, feedback, support chat) validates with `spoofing_protection: true`, which runs `file` to read the real type from the bytes, so a text file sent as `image/png` is rejected. The slim Ruby image does not ship `file`; without it, every upload fails. `test/ci/image_build_test.rb` checks the package.

`.github/workflows/deploy.yml` deploys main once CI is green on it. CI runs finish out of order, so its `latest` job first compares the commit with the tip of main and the deploy job runs only when they match: otherwise a green run for an older commit, arriving after a newer one deployed, would roll production back. The newer commit brings its own run.

The deploy job installs the gems before it loads the server key. Every gem's install code runs during `bundle install`, and with the key loaded it would run with root access to the server every app shares.

Only a push to the repository's own main deploys. The `workflow_run` branches filter matches the head branch of a pull request too, so without the event and head-repository checks a fork's branch named `main` would run its own code with the deploy secrets. The action that loads the server key is pinned to a commit SHA, because a tag can be moved; Dependabot's `github-actions` ecosystem keeps the pin current.
