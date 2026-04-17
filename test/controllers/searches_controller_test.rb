require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @conv = make_conversation(title: "Hit Me")
    Message.create!(conversation: @conv, record_type: "user", role: "user", position: 0,
                    text_content: "the quick brown fox jumped over the lazy dog")
  end

  test "empty query shows the prompt" do
    get search_path
    assert_response :success
    assert_match "Type a query", response.body
  end

  test "matching query returns the conversation" do
    get search_path(q: "brown fox")
    assert_response :success
    assert_match "Hit Me", response.body
  end

  test "no matches shows the empty state" do
    get search_path(q: "zzzzzz-no-such-term")
    assert_response :success
    assert_match(/No matches/, response.body)
  end

  test "does not surface messages from soft-deleted conversations" do
    @conv.soft_delete!
    get search_path(q: "brown fox")
    assert_response :success
    assert_no_match(/Hit Me/, response.body)
  end
end
