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

  test "unsupported_placeholder_text? matches the claude.ai fallback text" do
    assert unsupported_placeholder_text?("```\nThis block is not supported on your current device yet.\n```")
    assert unsupported_placeholder_text?("prefix This block is not supported on your current device yet. suffix")
    assert_not unsupported_placeholder_text?("hello world")
    assert_not unsupported_placeholder_text?(nil)
  end

  test "unsupported_block_notice renders a muted notice" do
    html = unsupported_block_notice
    assert_includes html, "Unsupported content"
    assert_includes html, "border-dashed"
    assert_includes html, "italic"
  end

  test "snippet_around does not return a snippet dominated by the placeholder" do
    text = "```\nThis block is not supported on your current device yet.\n```\nbut I found FOO here"
    snippet = snippet_around(text, "FOO")
    assert_includes snippet, "FOO"
    assert_includes snippet, "[unsupported content]"
    assert_not_includes snippet, "current device yet"
  end
end
