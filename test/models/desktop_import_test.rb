require "test_helper"

class DesktopImportTest < ActiveSupport::TestCase
  test "summary_line renders the per-import counters" do
    r = DesktopImport.create!(
      status: "succeeded", conversations_seen: 4, conversations_created: 2,
      conversations_updated: 1, conversations_skipped: 1, error_count: 0
    )
    assert_equal "seen=4 created=2 updated=1 skipped=1 errors=0", r.summary_line
  end

  test "recent sorts newest first" do
    a = DesktopImport.create!(status: "succeeded", created_at: 1.day.ago)
    b = DesktopImport.create!(status: "succeeded", created_at: 1.hour.ago)
    assert_equal [ b, a ], DesktopImport.recent.to_a
  end

  test "validates status" do
    r = DesktopImport.new(status: "???")
    assert_not r.valid?
    assert_includes r.errors[:status], "is not included in the list"
  end
end
