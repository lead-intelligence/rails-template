# Deploy

Kamal, configured in `config/deploy.yml`. Every value an app must replace is an UPPERCASE placeholder: the registry user, the server address, the host. `kamal setup` is the first deploy.

`.kamal/secrets` injects `RAILS_MASTER_KEY` from the gitignored master key and `OPENAI_API_KEY` from the environment; real values are never written into it. The `env` block also declares `APP_HOST` in clear and `SUPERADMIN_USER`, `SUPERADMIN_PASSWORD`, `ERROR_FEED_TOKEN`, `SMTP_USER_NAME` and `SMTP_PASSWORD` as secrets, which ship commented out in `.kamal/secrets`. A first deploy that leaves them out sends mailer links to `example.com`, sends no email, answers `401` on every developer panel and lets no watcher read the errors.

The `storage/` volume is mandatory, not an optimization. SQLite databases and locally-stored Active Storage files both live there, so a deploy without it loses the entire database on the next container rotation.

`SOLID_QUEUE_IN_PUMA` is set here, which is what makes the job supervisor run inside the web container (see background-jobs.md), and the backup accessory is active by default (see backups.md).

The image build reads `charco_mobile`, a private repository, with a read-only token: `Dockerfile` mounts `BUNDLE_GITHUB__COM` as a build secret on the `bundle install` layer and `config/deploy.yml` passes it under `builder`, so the token never lands in a layer. A build without it resolves every other gem and then fails on that one.

The runtime image installs the `file` command. Every photo upload (avatar, feedback, support chat) validates with `spoofing_protection: true`, which runs `file` to read the real type from the bytes, so a text file sent as `image/png` is rejected. The slim Ruby image does not ship `file`; without it, every upload fails. `test/ci/image_build_test.rb` checks the package.

`.github/workflows/deploy.yml` deploys main once CI is green on it. CI runs finish out of order, so its `latest` job first compares the commit with the tip of main and the deploy job runs only when they match: otherwise a green run for an older commit, arriving after a newer one deployed, would roll production back. The newer commit brings its own run.

The deploy job installs only the `deploy` group of the Gemfile, Kamal and its own gems, through `BUNDLE_ONLY`, with the versions and checksums of `Gemfile.lock`. Every gem's install code runs in that job, on the production server's runner, and the same job later loads the server key, root on the server every app shares, and writes the credentials key. Installing before loading the key is no fence: a process that install code leaves behind is still running when the key arrives. The app's other gems install inside the image build, which sees neither. Every action the job runs is pinned to a commit, because a tag can be moved to other code.

Only a push to the repository's own main deploys. The `workflow_run` branches filter matches the head branch of a pull request too, so without the event and head-repository checks a fork's branch named `main` would run its own code with the deploy secrets. The server key is a file on the deploy runner (`~/.ssh/peronix_deploy`), never a GitHub secret: a branch's workflows run on its pull request with every secret the repository can read, and agents write branches. Only this workflow from main reaches that runner (the organization's `deploy` runner group).

The app's own environment comes from the repository's secrets: the Deploy step hands each secret named `APP_<NAME>` to the container as `<NAME>`, and `config/deploy.yml` lists those names from `ATELIER_ENV`. The pass-through goes by prefix, so a few names are refused and the deploy stops before Kamal runs: `ATELIER_ENTER_KEY`, because it opens the passwordless sign-in link that belongs to staging, and `RAILS_MASTER_KEY` and `ATELIER_ENV`, which the deploy sets itself.
