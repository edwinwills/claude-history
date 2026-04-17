require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = make_project
    @conv = make_conversation(project: @project, title: "Real Convo")
    @other_conv = make_conversation(project: @project, title: "Other Convo",
                                    session_id: "other", file_path: "/tmp/other.jsonl")
    @label = Label.find_or_create_by_name!("plan")
    @conv.labels << @label
  end

  test "index renders projects without a label filter" do
    get root_path
    assert_response :success
    assert_match "Projects</h1>", response.body
  end

  test "index filters to labeled conversations when ?label= is set" do
    get root_path(label: "plan")
    assert_response :success
    assert_match "Conversations labeled", response.body
    assert_match @conv.display_title, response.body
    assert_no_match(/#{@other_conv.display_title}/, response.body)
  end

  test "unknown label falls back to projects view" do
    get root_path(label: "never-existed")
    assert_response :success
    assert_match "Projects</h1>", response.body
  end

  test "show renders the project with its conversations" do
    get project_path(@project)
    assert_response :success
    assert_match @conv.display_title, response.body
    assert_match @other_conv.display_title, response.body
  end

  test "show hides soft-deleted conversations" do
    @conv.soft_delete!
    get project_path(@project)
    assert_response :success
    assert_no_match(/#{@conv.display_title}/, response.body)
    assert_match @other_conv.display_title, response.body
  end
end
