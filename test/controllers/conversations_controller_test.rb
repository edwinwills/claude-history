require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = make_project
    @conversation = make_conversation(project: @project, title: "Hello World")
  end

  test "show renders" do
    get conversation_path(@conversation)
    assert_response :success
    assert_select "h1", /Hello World/
  end

  test "show is 404 for a soft-deleted conversation" do
    @conversation.soft_delete!
    get conversation_path(@conversation)
    assert_response :not_found
  end

  test "title action renders only the frame partial" do
    get title_conversation_path(@conversation, variant: "heading")
    assert_response :success
    assert_no_match(/<html/, response.body)
    assert_match(/turbo-frame/, response.body)
    assert_match(/conversation_title_heading_#{@conversation.id}/, response.body)
  end

  test "update sets custom_title and responds to turbo_stream" do
    patch conversation_path(@conversation),
          params: { conversation: { custom_title: "New Name" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "New Name", @conversation.reload.custom_title
    assert_match(/turbo-stream/, response.body)
    assert_match(/New Name/, response.body)
  end

  test "update with blank custom_title resets to derived title" do
    @conversation.update!(custom_title: "Something")
    patch conversation_path(@conversation), params: { conversation: { custom_title: "" } }
    @conversation.reload
    assert @conversation.custom_title.blank?
    assert_equal "Hello World", @conversation.display_title
  end

  test "destroy soft-deletes and redirects to project" do
    delete conversation_path(@conversation)
    assert_redirected_to project_path(@project)
    assert @conversation.reload.deleted?
  end

  test "restore clears deleted_at and redirects to the conversation" do
    @conversation.soft_delete!
    patch restore_conversation_path(@conversation)
    assert_redirected_to conversation_path(@conversation)
    assert_not @conversation.reload.deleted?
  end
end
