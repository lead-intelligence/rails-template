# Conventions

The rules every change follows, with the reason behind each. CLAUDE.md lists them in one line each; this page is where the reasons live.

Every Ruby and Rails command runs as `mise exec ruby@4.0.6 -- <command>` in a shell without mise shims, so the Ruby that answers is the one `.ruby-version` names.

## Tests first

The failing test comes first and the minimal implementation second. The coverage gate makes this mechanical: `test/test_helper.rb` demands 100% line and branch coverage, so code written before its test fails the suite until the test exists. A failing gate is closed with a test, never deleted or weakened. testing.md covers the gates themselves.

## Library first

Before writing anything, read the documentation of the gem that already solves it and use its documented way. Our own version of something a library covers is code nobody upstream maintains, and it drifts from the library on the next upgrade. Several pages here record a decision verified against a library's source; that record is what stops the next change from undoing it.

## Code style

Code, comments and identifiers are English. There are no code comments: the name of a method, a constant or a test carries the intent, and the architecture page carries the reason. There are no inline styles; DaisyUI component classes come before custom CSS, and custom CSS lives in `app/assets/tailwind/application.css` (see design.md).

## Copy

User-facing copy is never hardcoded. It goes through `t(...)` and lives in both `config/locales/es.yml` and `config/locales/en.yml`, Spanish default and English fallback. Tests assert keys, never copy. i18n.md has the gates that enforce it.

## Data scoping

Controllers reach records through `Current.user` — `Current.user.chats`, `Current.user.documents` — so a record that belongs to someone else is indistinguishable from one that does not exist. `ChatsController` and `DocumentsController` are the reference. Pundit is installed for the day that is not enough (see authorization.md).

## External calls in tests

Tests never reach the network. An LLM call in a test goes through `stub_openai_chat`, `stub_openai_chat_stream`, `stub_openai_chat_stream_with_tool_call` or `stub_openai_embedding` from `test/test_helpers/openai_stubs.rb`; any other request fails on WebMock (see testing.md).

## Background work

Background work goes to Solid Queue jobs, with `GenerateDocumentEmbeddingJob` as the reference. Solid Queue performs no automatic retry, so a job that has to retry declares `retry_on`; without it a failure waits in the failed-executions table (see background-jobs.md).

## Architecture rules

`Archspec.rb` states the architecture as rules that `archspec check` enforces in `bin/ci`, statically and in under a second. It starts from the Rails preset: models and helpers never depend on controllers, and never call `render`, `redirect_to`, `params`, `session`, `cookies` or `flash`. On top of it, a job never reads `Current`, because a job runs outside the request that set it; the job receives the record instead.

Logic lives in the model that owns it. The services, forms, decorators, presenters and components folders under app must stay empty, so a new behaviour goes on a model, a concern or a job, never in a parallel layer.

A violation is fixed in the code. A todo file or an `archspec:disable` comment silences the rule for every change after it, so neither is used. `archspec explain <file>` shows how a file was classified when a result is surprising.

## Quality gates

N+1 queries fail tests, in every kind of test. A real one is fixed with `includes`, `preload` or a counter cache; a safelist entry is for a verified false positive only, as narrow as one class and one association.

Accessibility failures fail system tests. Every `visit` audits the page against WCAG 2.1 A and AA in both colour schemes. The fix is in the markup or the palette; the ruleset is never widened.

## Business rules have one owner

A rule the person needs to know — a grace period, a cancellation window, an eligibility threshold — is a constant or a method on the model that enforces it. The sentence the person reads is generated from that value through i18n interpolation, and the value is never restated as a literal in copy. For example, a `Membership::GRACE_PERIOD` of two months pairs with a `memberships.rules.grace_period` key whose text interpolates `%{months}`.

The same key appears wherever the person needs it: on a rules page for whoever wants to read them all, and as a snippet in context where it matters — under the balance, next to the button that is disabled. Saying it twice costs nothing and cannot diverge. `User::DAILY_MESSAGE_LIMIT` and `Feedback::MESSAGE_MAX_LENGTH` follow this pattern today.

A stated rule that drifts from the enforced one is not a stale doc; it is a broken promise to someone who paid. This is a convention, not a rules engine. A rules engine is for rules that must change without a deploy, which is a much larger problem.

## Commits

Commit messages are a short imperative subject with no co-author trailers.

## Documentation

Three places serve three audiences. README.md is for whoever operates the app. CLAUDE.md is the map for agents: stack, commands, conventions and an index, loaded into every agent session, so it stays short. The architecture pages are the detail for agents: what each subsystem is, where its code lives, and the gotchas that break it.

A page is updated in the same commit as the behaviour it describes. A change to a subsystem that leaves its page untouched is unfinished, exactly like a change with no test.

Pages are written in present tense about the current state: no history, no session narrative, no "previously" or "now". There are no code blocks; a page points at the file instead. Each gotcha gets its own paragraph, stated as a consequence rather than a warning.

The app's name never appears in these pages, because the renamer does not rewrite them and the name would survive into every app born from here. Tooling that exists only in the template is never cited here either: a spawned app deletes it, and the documentation test there turns red.

`test/docs/documentation_test.rb` is the mechanical half. Every page the map points at exists and every page is in the map; no line of CLAUDE.md exceeds 300 characters; every page another page names exists; and every file path a page cites in backticks exists and is tracked, because a spawned app is a clone and an ignored file is absent there. That last check is what makes "up to date" verifiable: a renamed file with a stale page turns CI red.
