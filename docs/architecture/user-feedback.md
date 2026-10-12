# User feedback

A signed-in person leaves feedback, with optional screenshots, from the navbar dropdown at `/feedback`. Every submission is saved locally as a `Feedback` (`belongs_to :user`, `has_many_attached :photos`, validated for content type and size like the avatar). That part always works and needs no configuration.

On top of that, each feedback can open a GitHub issue. `after_create_commit` enqueues `CreateFeedbackIssueJob`, which returns immediately unless `GithubIssues.configured?` — both `GITHUB_ISSUES_TOKEN` and `GITHUB_ISSUES_REPO` set — and otherwise posts a `feedback`-labeled issue through `GithubIssues` (`app/models/github_issues.rb`), a small wrapper over `Net::HTTP` with no extra gem, sending `X-GitHub-Api-Version: 2022-11-28` per GitHub's own versioning header. The issue body carries the reporter, the app and environment, any captured context and photo links above a separator, and the person's own words below it.

The person's words go inside a code fence one backtick longer than the longest backtick run in them. Pasted as Markdown they would render, and an `@name` in them would notify that GitHub user; inside a fence they cannot close it early, and neither markup nor mentions take effect.

`Feedback::MESSAGE_MAX_LENGTH` (10,000 characters) caps the message, enforced by the model and mirrored by the form's `maxlength` and its `feedbacks.new.message_hint`, which interpolates the constant. GitHub rejects an issue body over 65,536 characters, and with no retry an oversized one would fail forever; the cap leaves the metadata ample room under that ceiling.

A non-2xx response raises, and nothing retries it. Solid Queue has no automatic retry mechanism and the job declares no `retry_on`, so a failed issue creation lands in `solid_queue_failed_executions` and waits there to be retried or discarded from `/jobs` or a console; Solid Errors records the exception either way. The local `Feedback` row is already saved by then, so nothing is lost — only the mirror to GitHub.

Photos are linked through the permanent public route `/feedback/photos/:signed_id` rather than a raw Active Storage URL, because those expire and GitHub cannot authenticate to fetch them. `FeedbackPhotosController` resolves the signed id and then checks the blob is actually attached to some `Feedback#photos` before redirecting, so it cannot be turned into a general "serve any blob by signed id" proxy for avatars or message attachments.

An upload can also arrive as the signed id of a blob, which is how direct uploads reach the form. Active Storage raises `ActiveSupport::MessageVerifier::InvalidSignature` for one that does not verify, and `ApplicationController` answers that with `422`, so a forged id on a feedback photo, a support chat photo or the avatar attaches nothing and never surfaces as a server error.

Those links are absolute URLs built from `config.action_mailer.default_url_options`, because a job has no request to infer a host from. In production the host comes from `APP_HOST` and falls back to `example.com`, so an app that deploys without setting it files issues whose photo links point nowhere.

The token is a GitHub fine-grained personal access token scoped to the single repository, with the Issues read-and-write repository permission and nothing else. Both variables live in `.env` (see `.env.example`).

Photos are whatever the person attaches. Nothing captures a screenshot of the page automatically, and the support chat's context capture carries plain text only.
