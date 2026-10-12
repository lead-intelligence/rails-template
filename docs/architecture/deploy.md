# Deploy

Kamal, configured in `config/deploy.yml`. Every value an app must replace is an UPPERCASE placeholder: the registry user, the server address, the host. `kamal setup` is the first deploy.

`.kamal/secrets` injects `RAILS_MASTER_KEY` from the gitignored master key and `OPENAI_API_KEY` from the environment; real values are never written into it. The `env` block also declares `APP_HOST` in clear and `SUPERADMIN_USER`, `SUPERADMIN_PASSWORD`, `ERROR_FEED_TOKEN`, `SMTP_USER_NAME` and `SMTP_PASSWORD` as secrets, which ship commented out in `.kamal/secrets`. A first deploy that leaves them out sends mailer links to `example.com`, sends no email, answers `401` on every developer panel and lets no watcher read the errors.

The `storage/` volume is mandatory, not an optimization. SQLite databases and locally-stored Active Storage files both live there, so a deploy without it loses the entire database on the next container rotation.

`SOLID_QUEUE_IN_PUMA` is set here, which is what makes the job supervisor run inside the web container (see background-jobs.md), and the backup accessory is active by default (see backups.md).

The image build forwards the SSH agent: `Dockerfile` mounts it on the `bundle install` layer and `config/deploy.yml` asks Kamal for it under `builder`. `charco_mobile` is fetched from a private repository over SSH, so a build without the agent resolves every other gem and then fails on that one. `test/ci/image_build_test.rb` keeps both halves together, since either alone builds nothing.
