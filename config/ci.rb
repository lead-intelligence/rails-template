CI.run do
  step "Style: Ruby", "bin/rubocop"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: Gem audit", "bin/bundler-audit"
  step "i18n: Translation health", "bin/i18n-tasks", "health"
  step "Native: Signals in views", "bundle", "exec", "charco_mobile", "check"
  step "Templates: Herb analyze", "bin/herb", "analyze", ".", "--no-timing"
  step "Tests: Rails", "bin/rails db:test:prepare test"
  step "Tests: System", "env", "SKIP_COVERAGE=1", "bin/rails", "db:test:prepare", "test:system"
  step "Smoke: renamed app boots and serves", "bin/smoke-rename"
end
