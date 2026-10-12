# Authorization

pundit is installed as a capability. **The app ships zero concrete policies**: scoping through `Current.user` remains the authorization until an app needs roles or shared resources.

`ApplicationController` includes `Pundit::Authorization`, overrides `pundit_user` to return `Current.user` — pundit defaults to a `current_user` method this app does not define — and rescues `Pundit::NotAuthorizedError` by redirecting back, falling back to the root path, with an alert. `ApplicationPolicy` (`app/policies/application_policy.rb`) is the generator's default-deny base with its comments stripped.

There is no `verify_authorized` or `verify_policy_scoped` anywhere, because they would force a policy onto every existing action. That strictness is opt-in per app: `after_action :verify_authorized` raises unless the action called `authorize`, `after_action :verify_policy_scoped` does the same for `policy_scope`, and `skip_authorization` or `skip_policy_scope` marks an action that legitimately has nothing to authorize.

The only policy in the repository is `PunditTestRecordPolicy` in `test/policies/`, for a test-only plain object, required by a glob in `test/test_helper.rb` and never loaded by app code — the same pattern as the test notifier. It is deliberately not a policy for a real model, so it can never silently merge with a policy a child app writes for that same model. `test/controllers/pundit_wiring_test.rb` exercises permit, deny with the rescue and alert, and scope filtering through a test-local controller and routes, touching no app controller.

Pundit earns its place with the first role (an admin, a moderator), the first shared resource (a document with viewers and editors) or the first rule beyond "the owner may do everything". Until then `Current.user` scoping is the authorization.

A policy is `bin/rails generate pundit:policy Document`, or a class under `app/policies/` that inherits from `ApplicationPolicy`, opens only the queries it allows — `show?` and `update?` comparing `record.user` with `user` — and narrows a nested `Scope#resolve`. `ApplicationPolicy` answers `false` to everything, so a policy grants only what it opens. In a controller `authorize document` asks the query named after the action (`update?` inside `update`), returns the record when allowed and raises `Pundit::NotAuthorizedError` otherwise, which the rescue turns into the redirect with an alert. `policy_scope(Document)` runs `Scope#resolve` for index actions, and the `policy` helper drives conditional UI in views, such as `policy(document).update?` around an edit link.
