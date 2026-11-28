require "test_helper"
require "open3"

class RerunFailedTestsTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin/rerun-failed-tests").to_s

  test "a failed step that is not a test is a real failure: nothing runs again" do
    status, said = rerun(<<~LOG)
      \e[1;31m❌ Style: Ruby failed in 3.21s\e[0m
      Failure:
      QuoteTest#test_x [test/models/quote_test.rb:42]:
      bin/rails test test/models/quote_test.rb:42
      ❌ Continuous Integration failed in 5m
    LOG

    assert_equal 1, status
    assert_includes said, "Style: Ruby"
  end

  test "a failed run that names no test runs nothing again" do
    status, said = rerun("❌ Tests: System failed in 3m\nChrome died\n")

    assert_equal 1, status
    assert_includes said, "names no failed test"
  end

  test "coverage below the minimum is a real failure, though tests also failed" do
    status, said = rerun(<<~LOG)
      Failure:
      bin/rails test test/models/quote_test.rb:42
      Line coverage (99.1%) is below the expected minimum coverage (100.00%).
      ❌ Tests: Rails failed in 2m
    LOG

    assert_equal 1, status
    assert_includes said, "coverage"
  end

  test "when only tests failed, it runs them again alone, with no coverage" do
    status, said = rerun(<<~LOG, "RERUN_RAILS" => "true")
      \e[31mFailure:\e[0m
      PatientsTest#test_y [test/system/patients_test.rb:187]:
      bin/rails test test/system/patients_test.rb:187
      bin/rails test test/system/patients_test.rb:187
      bin/rails test test/models/quote_test.rb:42
      ❌ Tests: System failed in 6m
      ❌ Tests: Rails failed in 2m
      ❌ Continuous Integration failed in 9m
    LOG

    assert_equal 0, status
    assert_includes said, "SKIP_COVERAGE=1 bin/rails test test/system/patients_test.rb:187 test/models/quote_test.rb:42"
  end

  private

  def rerun(log, env = {})
    Dir.mktmpdir do |dir|
      path = File.join(dir, "ci.log")
      File.write(path, log)
      said, status = Open3.capture2e(env, SCRIPT, path)
      [ status.exitstatus, said ]
    end
  end
end
