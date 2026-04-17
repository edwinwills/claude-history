require "test_helper"

class ProjectsControllerFilterTest < ActionDispatch::IntegrationTest
  setup do
    @code_proj = Project.create!(path: "/Users/me/code/a", name: "a")
    @desktop_proj = Project.create!(path: "claude-desktop-export", name: "Claude Desktop")
    @c = make_conversation(project: @code_proj, session_id: "c1", file_path: "/tmp/c1.jsonl", title: "Code Convo")
    @d = make_conversation(project: @desktop_proj, session_id: "d1", file_path: "desktop-export:d1", title: "Desktop Convo", source: "desktop")
  end

  test "index without filter shows both sources" do
    get root_path
    assert_response :success
    assert_match @code_proj.name, response.body
    assert_match @desktop_proj.name, response.body
  end

  test "?source=code hides desktop projects" do
    get root_path(source: "code")
    assert_response :success
    assert_match @code_proj.name, response.body
    assert_no_match(/Claude Desktop/, response.body)
  end

  test "?source=desktop hides code projects" do
    get root_path(source: "desktop")
    assert_response :success
    assert_no_match(/>a<\/a>/, response.body)
    assert_match @desktop_proj.name, response.body
  end

  test "unknown ?source= value is ignored" do
    get root_path(source: "bogus")
    assert_response :success
    assert_match @code_proj.name, response.body
    assert_match @desktop_proj.name, response.body
  end

  test "combines with ?label= filter" do
    label = Label.find_or_create_by_name!("plan")
    @c.labels << label
    @d.labels << label

    get root_path(label: "plan", source: "code")
    assert_response :success
    assert_match @c.display_title, response.body
    assert_no_match(/#{@d.display_title}/, response.body)
  end
end
