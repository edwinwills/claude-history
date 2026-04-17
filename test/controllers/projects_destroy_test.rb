require "test_helper"

class ProjectsDestroyTest < ActionDispatch::IntegrationTest
  setup do
    @project = make_project(path: "/Users/me/code/cooltown")
    @live = make_conversation(project: @project, session_id: "live1", file_path: "/tmp/live1.jsonl", title: "Stays")
    @pre_deleted = make_conversation(project: @project, session_id: "pre1", file_path: "/tmp/pre1.jsonl", title: "Already gone")
    @pre_deleted.soft_delete!
    sleep 0.01 # ensure project's batch timestamp is distinct from the individual pre-delete
    @project.update!(conversation_count: 2)
  end

  test "destroy soft-deletes the project and its active conversations" do
    delete project_path(@project)
    assert_redirected_to root_path

    assert_nil Project.find_by(id: @project.id), "project should be hidden by default scope"
    assert Project.with_deleted.find(@project.id).deleted?

    assert_nil Conversation.find_by(session_id: "live1"), "live conversation should be cascaded into trash"
    assert Conversation.with_deleted.find_by(session_id: "live1").deleted?
  end

  test "deleted project is hidden from projects index and show" do
    @project.soft_delete!
    get root_path
    assert_no_match(/cooltown/, response.body)

    get project_path(@project)
    assert_response :not_found
  end

  test "restore brings back the project and the batch-deleted conversations only" do
    @project.soft_delete!
    batch_ts = @project.reload.deleted_at

    patch restore_project_path(@project)
    assert_redirected_to project_path(@project)

    assert Project.exists?(@project.id)
    live = Conversation.find_by(session_id: "live1")
    assert_not_nil live, "batch-deleted conversation should be restored"
    assert_nil live.deleted_at

    # individually-deleted-before conversation stays in trash
    pre = Conversation.with_deleted.find_by(session_id: "pre1")
    assert pre.deleted?, "pre-deleted conversation should remain in trash after project restore"
  end

  test "trash index shows deleted projects and excludes their conversations from the individual section" do
    @project.soft_delete!
    get trash_path
    assert_response :success

    # Project appears in Projects section
    assert_match(/cooltown/, response.body)
    # live1 was cascade-deleted with project — should NOT appear in Conversations section
    assert_no_match(/Stays</, response.body)
    # pre1 was individually deleted (project wasn't deleted at the time) —
    # now the project IS deleted so it's also excluded
    assert_no_match(/Already gone</, response.body)
  end
end
