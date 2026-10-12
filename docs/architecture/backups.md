# Backups

kamal-backup is wired as a Kamal accessory: encrypted, deduplicated, scheduled restic snapshots to any restic or rclone remote — S3, B2, SFTP and so on.

`config/kamal-backup.yml` snapshots the four SQLite databases *consistently*, declaring each as a sqlite adapter rather than copying files, and separately takes the Active Storage files by path; kamal-backup excludes the raw database, write-ahead-log and shared-memory files from the path sweep because it already captures them as databases. The restic repository is initialized on first use and the schedule is daily (`1d`), which is a starting point rather than a recommendation; a smaller data-loss window is a shorter `backup.schedule`, such as `1h`. The uploads are the `/rails/storage` entry under `paths`.

The accessory block in `config/deploy.yml` is **active by default**, not a commented example like the database accessories. It mounts the app's storage volume plus a state volume for the backup tool, mounts the configuration file, and pulls `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from `.kamal/secrets`, where they ship commented out.

Being active, it fails to boot until the repository is set and those secrets are uncommented. That is intentional and matches the deny-by-default stance elsewhere: decide about backups before there is real data, not after.

Restoring and inspecting go through the tool's own `backup`, `list` and `evidence` commands. Practise a restore into a scratch target before needing one.
