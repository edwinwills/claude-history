require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "display_title prefers custom_title over title over slug" do
    c = make_conversation(title: "Derived", slug: "hello-world", custom_title: "My Custom")
    assert_equal "My Custom", c.display_title

    c.custom_title = nil
    assert_equal "Derived", c.display_title

    c.title = nil
    assert_equal "Hello world", c.display_title  # Ruby's String#capitalize: first char only

    c.slug = nil
    assert_match(/\(untitled session /, c.display_title)
  end

  test "resume_command includes cwd and session_id" do
    c = make_conversation(cwd: "/tmp/my proj", session_id: "abc-123")
    assert_equal "cd /tmp/my\\ proj && claude --resume abc-123", c.resume_command
  end

  test "default_scope hides soft-deleted conversations" do
    c = make_conversation
    c.soft_delete!
    assert_not Conversation.exists?(c.id)
    assert Conversation.with_deleted.exists?(c.id)
    assert Conversation.deleted.exists?(c.id)
  end

  test "soft_delete! sets deleted_at; restore! clears it" do
    c = make_conversation
    assert_nil c.deleted_at
    c.soft_delete!
    assert c.deleted?
    c.restore!
    assert_not c.deleted?
  end

  test "with_label_name scope filters by label name case-insensitively" do
    c1 = make_conversation
    c2 = make_conversation(session_id: "c2", file_path: "/tmp/c2.jsonl")
    label = Label.find_or_create_by_name!("Bug")
    c1.labels << label

    assert_includes Conversation.with_label_name("bug"), c1
    assert_not_includes Conversation.with_label_name("bug"), c2
  end

  test "display_messages returns only user and assistant records" do
    c = make_conversation
    Message.create!(conversation: c, record_type: "user", role: "user", position: 0, text_content: "hi")
    Message.create!(conversation: c, record_type: "assistant", role: "assistant", position: 1, text_content: "hey")
    Message.create!(conversation: c, record_type: "system", position: 2, text_content: "meta")
    Message.create!(conversation: c, record_type: "progress", position: 3, text_content: "")

    assert_equal 2, c.display_messages.count
  end
end
