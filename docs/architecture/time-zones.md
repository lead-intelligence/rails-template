# Time zones

Rails stores every time in UTC and converts it when a view formats it, using `Time.zone`. Each person sees times in their own zone, and nobody chooses it: the browser reports it.

The `time-zone` Stimulus controller sits on the `body` of the application layout. On every page it reads the zone from `Intl.DateTimeFormat` and writes it to the `time_zone` cookie when the cookie holds a different one. The first page a browser loads still renders in the app default, and every later page follows the cookie.

`ApplicationController#switch_time_zone` is an `around_action` that runs each request inside `Time.use_zone`. It takes the cookie when `ActiveSupport::TimeZone` knows the name, else the signed-in person's stored zone, else the app default. A name it does not know is ignored, so a forged cookie changes nothing.

`User#time_zone` stores the zone, because a job has no request and no cookie. `User#remember_time_zone` writes it with `update_column` only when the cookie differs from it, so a page load does not write to the database. `User#zone` returns the stored zone or the app default.

`ChatResponseJob` renders and broadcasts the assistant's reply, so it wraps the response in `Time.use_zone(chat.user.zone)`. Without it the reply's time comes out in UTC while the person's own message, rendered in the request, shows the local time. Any new job that renders a time for a person must do the same.

The daily message quota follows the person's day. `User#messages_sent_today` compares the stored day with `Date.current`, and the count happens in the request, inside the person's zone, so the quota starts again at local midnight and not at UTC midnight.

The browser may report a legacy alias for a zone, such as `America/Buenos_Aires` for `America/Argentina/Buenos_Aires`. `ActiveSupport::TimeZone` resolves both through TZInfo, so the alias is stored as reported and behaves the same.

Zones come from the `tzinfo-data` gem, bundled on every platform, and never from the operating system. Browsers still report legacy names such as `America/Buenos_Aires`, and Debian, the base of the production and CI images, moved those names to a separate `tzdata-legacy` package. Read from the system files, such a name resolves to no zone, and the person silently stays in the default zone.
