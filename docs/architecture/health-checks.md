# Health checks

Two endpoints with different jobs. `/up` is Rails' shallow liveness probe and Kamal's proxy uses it to gate deploys and container rotation — keep it shallow, and note that `config/environments/production.rb` excludes it from the SSL redirect and silences it in the logs. `GET /health` (`HealthController`, public by design) renders `HealthCheck.call` (`app/models/health_check.rb`) as JSON: `200` when every check passes, `503` with the failing one marked as an error. The body is a `status` of `ok` or `error` and a `checks` object naming each check, so a monitor only has to watch the status code. Nothing watches it until an app points an uptime monitor at it.

Two checks ship. `database` runs a trivial query on the primary connection. `jobs` looks for a Solid Queue supervisor whose heartbeat is inside `SolidQueue.process_alive_threshold` — the gem's own liveness window rather than an invented number.

The supervisor's `kind` is never plain `Supervisor`: Solid Queue writes `Supervisor(fork)` or `Supervisor(async)`, so the check matches with `LIKE`. An exact match compiles, passes review and reports the queue dead forever. Detection also lags by up to the threshold: a graceful shutdown deregisters and goes red immediately, while an abrupt kill leaves a fresh heartbeat behind for a few minutes.

The `jobs` check is included only when the Active Job adapter is Solid Queue's — true in development and production, false in test — so the suite's job behaviour is unaffected by the endpoint existing.

It exists because the supervisor runs inside Puma. A dead supervisor leaves Puma serving pages and `/up` green while email, embeddings, chat replies, data exports and feedback tickets stop silently. The endpoint is public rather than superadmin-gated because the superadmin gate is deny-by-default: an unconfigured app would answer `401`, which every uptime monitor reads as an outage. Adding a check is one line in `HealthCheck#call`.

Gating it anyway means including `SuperadminAuthentication` in `HealthController` and giving the monitor the credentials. `test/models/health_check_test.rb` registers a real `SolidQueue::Process` row against the test queue database (see background-jobs.md), so the jobs check runs against real rows rather than stubs.
