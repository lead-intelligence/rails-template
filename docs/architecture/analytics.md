# Analytics

`ahoy_matey` ships as a capability, not as instrumentation — the same stance as noticed and pundit. The tables, the privacy configuration, the retention job and the wiring are all here; **zero events are tracked**, because what is worth measuring is a per-app product decision. `Ahoy::Visit` and `Ahoy::Event` (`app/models/ahoy/`) live in the primary database.

`config/initializers/ahoy.rb` sets the privacy defaults: `Ahoy.cookies = :none`, so there is no tracking cookie and nothing to ask consent for; `Ahoy.mask_ips = true`; `Ahoy.geocode = false`, and the migration was trimmed of the location and native-app columns accordingly, which is safe because `Ahoy::DatabaseStore#slice_data` drops any column the model doesn't declare. `Ahoy.api = false` means server-side tracking only — no JavaScript, no public events endpoint, nothing for the Content Security Policy to allow. Bots are excluded by default, which is why integration tests that send no browser user agent create no visits at all.

`User` declares `has_many :ahoy_visits` and `:ahoy_events` with `dependent: :destroy`, which puts analytics inside both the deletion cascade and the data export for free. `Ahoy::Visit::RETENTION` is 90 days and `purge_expired_visits` in `config/recurring.yml` sweeps nightly.

The sweep finds `Ahoy::Visit.expired` through the `started_at` index; Ahoy's own `visitor_token, started_at` index cannot serve a range on its second column. Without it each purge scans the whole visits table while it holds SQLite's single write lock, so every other write waits for a scan that grows with traffic: about 300 ms at 900,000 visits, against 145 ms with the index.

Two wiring details fail silently if changed. `Ahoy.user_method` is overridden to return `Current.user`, because Ahoy looks for a `current_user` method this app does not define — the same override as `pundit_user`. And `ApplicationController` re-registers Ahoy's callback after its own `resume_session`, because sessions here resolve lazily: without that ordering, `Current.session` is not set until the layout renders, long after every `before_action`, and every visit on a publicly reachable page is recorded as anonymous even for a signed-in person.

`Ahoy::Visit` is one row per visit, created on the server: referrer and referring domain, landing page, UTM parameters, browser, OS, device type, the masked IP and the signed-in user. `Ahoy::Event` holds only what an app chooses to track, with JSON properties. Both are ordinary Active Record models, so behaviour joins against the app's own tables — the reason to keep analytics first-party.

Adding a measurement is three steps. Track it where it happens: every controller has `ahoy`, and `ahoy.track "Document created", document_id: document.id` records an event. The name is the key it is queried by forever, so a stable human phrase ages better than a versioned code, and the properties are identifiers and small scalars, never whole records. Query it with `Ahoy::Event.where(name:)`, `Ahoy::Event.where_event(name, properties)` or a `group(:user_id).count`; no dashboard ships, and the queries worth writing join events to the domain, which a third-party tool cannot do. Then decide retention: these are the fastest-growing tables in an app that uses them, on SQLite on one volume, so shorten `Ahoy::Visit::RETENTION` rather than lengthen it.

A UI over the data is a madmin dashboard, generated with `bin/rails g madmin:resource Ahoy::Visit` and routed like the others (see superadmin-panels.md).

`Ahoy.mask_ips` zeroes the last octet of an IPv4 address and the last 80 bits of an IPv6 one before storage. With no tracking cookie, visitors are grouped into anonymity sets, which is what makes a cookie-consent banner unnecessary.

Client-side tracking is off. Turning it on is `Ahoy.api = true`, vendoring the script with `bin/importmap pin ahoy.js --download` and importing `ahoy` in `app/javascript/application.js`; the endpoint is same-origin, so the Content Security Policy still holds.
