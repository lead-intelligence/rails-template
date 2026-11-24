require "test_helper"

class ErrorHistoryTest < ActiveSupport::TestCase
  test "purges old occurrences whether or not their error was resolved" do
    unresolved = create_error
    old = unresolved.occurrences.create!(backtrace: "", context: {}, created_at: (SolidErrors.destroy_after + 1.day).ago)
    recent = unresolved.occurrences.create!(backtrace: "", context: {}, created_at: 1.day.ago)

    ErrorHistory.purge_expired

    assert_not SolidErrors::Occurrence.exists?(old.id)
    assert SolidErrors::Occurrence.exists?(recent.id)
    assert SolidErrors::Error.exists?(unresolved.id)
  end

  private

  def create_error
    SolidErrors::Error.create!(exception_class: "NoMethodError", message: "boom", severity: "error", fingerprint: SecureRandom.hex(32))
  end
end
