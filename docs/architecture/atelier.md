# Atelier

Atelier is the platform that builds and runs this app for its owner. It reaches the app only through the tasks in `lib/tasks/atelier.rake`, so it never needs to know how the models look.

`atelier:owner` makes the owner's account from `EMAIL` and `PASSWORD` in the environment, confirmed, and exits 3 without changing anything when the account already exists. Staging runs it before the seeds, so the owner is the oldest account there.

`atelier:people` prints who a tester can sign in as: one line per account, the email, a tab, then a label in the default locale. The owner comes first: the oldest account that can sign in and is outside `User::DEMO_DOMAIN`. The demo accounts follow in the order they were made. The seeds make them with `User.demo_account!`, whose email is the role at the demo domain, and the label is the `atelier.people.<role>` key, or the account's name when the key is missing. An unconfirmed account, or one waiting for deletion, is never listed.

`GET /atelier/enter?token=TOKEN` signs a tester in without a password, on staging only. The route exists only while `ATELIER_ENTER_KEY` is set, and production never sets it; without it the path answers 404. The token is a payload, a dot, and a signature. The payload is the JSON object with `email` and `exp` (Unix seconds), encoded as base64url without padding. The signature is the lowercase hex HMAC-SHA256 of the payload text, keyed with the `ATELIER_ENTER_KEY` string. `atelier_token` in `test/test_helpers/atelier_token_helper.rb` builds one, and a test pins its output for a fixed key, email and time.

`AtelierEntriesController` checks the token with `User.from_atelier_token`: a wrong signature, a past `exp`, a payload that is not that JSON object, or an account that could not sign in with its password (unknown, unconfirmed or waiting for deletion) all redirect to the sign-in page with the `atelier_entries.show.alert` alert. A good token starts a new session exactly as a password sign-in does and redirects to the root. The `token` parameter is filtered from the logs by `config/initializers/filter_parameter_logging.rb`.
