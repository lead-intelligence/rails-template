# Testing

`bin/ci` is the pre-commit gate and exactly what CI runs: Rails' native CI runner, with its steps listed in `config/ci.rb`. `bin/rails test` runs the unit and integration suites and measures coverage; `bin/rails test:system` runs the browser suite and is not part of `bin/rails test`.

## Network

Tests never hit the network. `test/test_helper.rb` calls `WebMock.disable_net_connect!(allow_localhost: true)`, so a real HTTP call from a test fails loudly instead of reaching OpenAI. `.env.test` carries a fake `OPENAI_API_KEY` so the app boots in the test environment before WebMock installs its stubs.

RubyLLM calls are stubbed through `test/test_helpers/openai_stubs.rb`: `stub_openai_chat(content:)` for a chat completion, `stub_openai_chat_stream(chunks:)` for a streamed one, `stub_openai_chat_stream_with_tool_call(tool_name:, arguments:, chunks:)` for a streamed tool-call round trip — a tool-call chunk, then a final streamed reply — and `stub_openai_embedding(vector:)` for an embedding.

Two CI steps reach the network anyway. `bin/bundler-audit` checks the locked gems against the ruby-advisory-db, which the gem does not vendor: the first run clones it into `~/.local/share/ruby-advisory-db`, and every later run reuses that copy however old, since the binstub never passes `--update`. A scan that must reflect a point in time caches or pins that directory. `bin/brakeman --ensure-latest`, Rails' own binstub, asks rubygems.org on every run, so CI can fail on the day brakeman ships a release, with no code change.

## Coverage

`test/test_helper.rb` sets `minimum_coverage line: 100, branch: 100` over `app/` and `lib/`, measured on the `bin/rails test` run, so the suite fails the moment either number drops. Any subset of the suite fails that gate at the end even when every assertion passes; `SKIP_COVERAGE=1` turns measurement off while iterating.

`simplecov-console` prints every file under 100% with its uncovered line numbers in the `missing` column and its uncovered branches, so the terminal says what to cover without opening the HTML report. Exclusions use `skip`, not the deprecated `add_filter`; the madmin files are the main ones (see superadmin-panels.md).

System tests run with `SKIP_COVERAGE=1` (set in `test/application_system_test_case.rb` and in the system step of `config/ci.rb`), because browser-driven runs would double-count or skew the figures of the unit run.

## System tests

The system suite drives headless Chrome through cuprite, Ferrum over the DevTools protocol, configured in `test/application_system_test_case.rb`. Cuprite talks to Chrome without a WebDriver layer and delivers clicks and keystrokes reliably, so the tests use plain Capybara with no `execute_script` workarounds; Selenium's synthetic input dropped intermittently on the CI runner. `Capybara.disable_animation = true` keeps DaisyUI transitions from intercepting an interaction. The CI runner already ships Chrome.

The suite runs in parallel, one browser and one Puma server per worker, through `parallelize(threshold: 10)`; Rails' default threshold of 50 would keep it in one process. A single file stays serial. A worker that crashes leaves the run hanging instead of failing, so a system step that never finishes means a crashed worker: its output holds a `[BUG]` line.

## N+1 detection

Bullet fails a test on an N+1 or on an eager load that is never used. `config/environments/test.rb` sets `Bullet.enable` and `Bullet.raise`; `config/environments/development.rb` only logs, to `log/bullet.log` and the browser console.

`test/test_helper.rb` wraps every test in `Bullet.start_request` and `Bullet.end_request`, as Bullet's Minitest guide recommends. Controller, integration and system tests already pass through Bullet's Rack middleware, but a model test that touches associations directly does not, and without the wrapper the strict mode would not reach it. System tests are covered by the middleware on the in-process Puma thread, and Capybara's `raise_server_errors` re-raises the failure in the test.

"USE eager loading" in the failure means a real N+1: add the suggested `includes` or `preload`, or the counter cache it names. "AVOID eager loading" means the eager load was not used on this path: either it is unnecessary and goes, or it serves another caller that this test does not exercise. Only that second case earns a safelist entry, with the exact class and association and never a whole detector. The `TestNotifier::Notification` entry for `:event` in `config/environments/test.rb` is the model: the helper test calls `recent_notifications` without rendering a message, while the navbar bell always renders one.

## Accessibility

Every `visit` in a system test audits the page with axe-core against WCAG 2.1 A and AA, and a violation fails the test. `assert_accessible` in `test/test_helpers/accessibility_helper.rb` runs right after `assert_turbo_ready` in `ApplicationSystemTestCase#visit`, so nobody has to remember to call it. A failure names the rule, its impact, the Deque help URL and the offending selectors.

Every page is audited twice. The helper forces `prefers-color-scheme` to light and then dark through the CDP `Emulation.setEmulatedMedia` command and resets it afterwards, and the failure names the scheme. Headless Chrome's default scheme differs per machine — dark on one laptop, light on the GitHub runner — so a single-scheme audit passed on one and failed on the other. The two passes cost about 5 seconds over the suite; axe itself costs about 1.2 seconds, because it is injected once per page load and Turbo keeps it alive across in-page navigations.

The Content Security Policy does not block the audit: axe is injected over the DevTools protocol, which the page's `script-src` does not govern.

`axe-core-api` is installed only for its vendored `axe.min.js`. Its own runner is Selenium-specific — it calls `manage.timeouts` and `switch_to.window` and rescues Selenium errors — and its legacy path calls `execute_async_script`, which cuprite does not implement. The helper injects the gem's script and drives `axe.run` through Capybara's `evaluate_async_script`. `axe-core-capybara` is absent because its only entry point forces the Selenium driver.

The engine panels — madmin, Mission Control, Solid Errors, onlylogs — are not system-tested, so their markup is never audited; the RailsPress admin test opts out of the audit for the engine's own markup (see blog.md). A new system test that visits an engine panel gets the same narrow opt-out rather than a weaker rule for the whole app.
