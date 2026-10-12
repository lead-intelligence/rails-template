# Console auditing

console1984 records production console sessions and the commands run in them. It depends on Active Record Encryption, whose keys live in `config/credentials.yml.enc` and are generated with `bin/rails db:encryption:init`.

`config/credentials.yml.enc` travels with the repository and the master key that opens it never does, so a new app has to generate its own credentials before the console — or anything else that decrypts — will boot in production. The steps are: delete `config/credentials.yml.enc`, run `bin/rails credentials:edit` to create a fresh master key and credentials file with a new `secret_key_base`, run `bin/rails db:encryption:init`, and copy the three keys it prints (`primary_key`, `deterministic_key`, `key_derivation_salt`) into an `active_record_encryption:` block of the credentials.

Every session and every command is a row in `console1984_sessions` and `console1984_commands`. Only the production environment is protected; development and test consoles are unrestricted. No web UI ships for the audit trail; console1984's companion gem audits1984 adds one.
