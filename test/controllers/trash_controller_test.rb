require "test_helper"

class TrashControllerTest < ActionDispatch::IntegrationTest
  test "index shows only soft-deleted conversations" do
    live = make_conversation(title: "Still here")
    trashed = make_conversation(title: "Deleted one", session_id: "d2", file_path: "/tmp/d2.jsonl")
    trashed.soft_delete!

    get trash_path
    assert_response :success
    assert_match "Deleted one", response.body
    assert_no_match(/Still here/, response.body)
  end

  test "empty trash shows an empty state" do
    Conversation.deleted.destroy_all
    get trash_path
    assert_response :success
    assert_match(/Trash is empty/, response.body)
  end
end
