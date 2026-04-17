require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "desktop? is true for claude-desktop-prefixed paths" do
    code = Project.create!(path: "/Users/me/code/repo", name: "repo")
    desktop = Project.create!(path: "claude-desktop-export", name: "Claude Desktop")
    team_org = Project.create!(path: "claude-desktop:abc-123", name: "Claude Desktop · Team")

    assert code.code?
    assert_equal "code", code.source

    assert desktop.desktop?
    assert_equal "desktop", desktop.source

    assert team_org.desktop?
    assert_equal "desktop", team_org.source
  end

  test "code and desktop scopes partition projects correctly" do
    Project.create!(path: "/Users/me/code/a", name: "a")
    Project.create!(path: "/Users/me/code/b", name: "b")
    Project.create!(path: "claude-desktop-export", name: "Claude Desktop")

    assert_equal 2, Project.code.count
    assert_equal 1, Project.desktop.count
  end
end
