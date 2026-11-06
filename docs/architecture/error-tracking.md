# Error tracking

Solid Errors subscribes to `Rails.error` from `config/initializers/solid_errors.rb` and persists deduplicated exceptions to the primary database — no separate database, migrated like everything else. The dashboard is mounted at `/errors` and gated by the shared superadmin basic auth: the initializer sets `SolidErrors.base_controller_class` to `SolidErrorsBaseController`, which only includes `SuperadminAuthentication`. The gem's own username and password settings are deliberately left unset, which leaves its internal `http_basic_authenticate_with` inert, so the deny-by-default concern is the only gate.

Email notification is the one panel-specific setting: the recipient resolves from `Rails.application.credentials.dig(:solid_errors, :email_to)` and then `SOLID_ERRORS_EMAIL_TO`, and notifications only fire when one of them resolves. Solid Errors mails on every occurrence, not only on a new error.

`SolidErrors.destroy_after` is 30 days. The gem then deletes the occurrences of resolved errors older than that, and the resolved errors left with none, on every hundredth new occurrence. Unresolved errors stay until someone resolves them.

Browser exceptions land in the same dashboard; see browser-errors.md.

## Error feed

`GET /error_feed` lets a watcher outside the app read new errors without a shell or the dashboard. `ErrorFeedsController` answers; `ErrorFeed` (`app/models/error_feed.rb`) builds the page.

It returns Solid Errors occurrences with an id above `since` (default `0`), oldest first, at most 100 per page, plus `next_cursor` and `more`. The cursor is the occurrence id, not a timestamp: timestamps tie and would drop or repeat rows at a page edge. The id cursor never skips a row only because of SQLite: the tables use `AUTOINCREMENT`, so a deleted id is never reused, and one writer at a time means ids commit in order. On a database with concurrent writers, ids can commit out of order and this cursor would need rethinking. Call again with `since=next_cursor` while `more` is true. Each occurrence carries its id and time, and its error's fingerprint, class, message (cut to 500 characters), severity, source, resolved flag, first and last seen, total occurrence count, up to five of the app's own backtrace frames, and its route. Count, last seen and resolved describe the error now, not at that occurrence.

Count and last seen are computed over every occurrence of each error on the page. Last seen reads the `solid_errors_occurrences` index on `error_id` and `created_at`; without it a page with one new occurrence of an error seen 100,000 times reads all those rows, about 30 ms instead of 9. `test/models/error_feed_test.rb` asserts the query plan.

The route is the matched pattern, such as `GET /passwords/:token/edit(.:format)`, never the raw path, which can carry reset tokens and ids. Solid Errors records no path, so `ErrorRoute` (`app/errors/error_route.rb`), registered in the initializer as a `Rails.error` middleware, adds it to the context of request errors: unhandled ones, and those the app reports itself with the default source. A report with its own source describes somewhere else, so it gets none. Browser errors, reported with source `javascript` from `POST /javascript_errors`, would otherwise all carry that endpoint's route. Jobs have none either. The middleware runs before Solid Errors' subscriber, which in 0.9.x turns the controller in the context into a `"Class#action"` string, so `ErrorRoute` still sees the request.

Set a token to turn it on: `error_feed_token` in credentials, or `ERROR_FEED_TOKEN`. The watcher sends `Authorization: Bearer <token>`, compared in constant time. Without a token the endpoint answers `404`, a wrong or missing one gets `401`, and more than 60 requests a minute get `429`.

It never exposes the occurrence context: no params, cookies, headers, URLs, user agents or user ids. Only what the error says about itself, plus the route pattern. Backtrace frames show `[PROJECT_ROOT]` in place of the server's paths.

## Telling Peronix

Peronix hears of each new error as it happens, and an agent investigates and fixes it. Solid Errors 0.9 instruments `error_created.solid_errors` when an occurrence opens a new error and `error_reopened.solid_errors` when it opens one that was resolved, after the occurrence commits; an error seen again while open sends neither. The initializer subscribes to both and calls `ErrorReportJob.report_later` with that occurrence, which queues the job only while `PeronixErrors.configured?`. The job posts `ErrorFeed.entry` of the occurrence, the same shape the feed serves, to the Peronix address with `Authorization: Bearer <token>` (`PeronixErrors`); a refusal or a network failure runs again later, up to 10 times. It is an event, not a concern included into `SolidErrors::Error`: a concern loaded at boot escapes SimpleCov and never counts as covered.

Peronix writes the address and the app's own token into the app's credentials when it makes the app (`peronix: { errors_url:, errors_token: }`), so a new app tells Peronix with no setup; `PERONIX_ERRORS_URL` and `PERONIX_ERRORS_TOKEN` stand in when the credentials have none. Unset, the app tells nobody.
