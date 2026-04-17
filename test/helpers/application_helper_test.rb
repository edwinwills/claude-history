require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "source_badge renders a pill with distinct color per source" do
    code = source_badge("code")
    desktop = source_badge("desktop")
    assert_includes code, "Code"
    assert_includes code, "bg-primary/10"
    assert_includes desktop, "Desktop"
    assert_includes desktop, "bg-secondary"
  end

  test "source_badge honours :sm size" do
    small = source_badge("code", size: :sm)
    default = source_badge("code")
    assert_includes small, "text-[9px]"
    assert_includes default, "text-[10px]"
  end

  test "source_badge falls back for unknown sources" do
    html = source_badge("something-weird")
    assert_includes html, "Something Weird"
  end
end
