require "test_helper"

class ClaudeDesktop::ImporterTest < ActiveSupport::TestCase
  class FakeClient
    def initialize(orgs:, convs_by_org:, details_by_uuid:)
      @orgs = orgs
      @convs_by_org = convs_by_org
      @details_by_uuid = details_by_uuid
    end

    def organizations; @orgs; end
    def conversations(org_uuid); @convs_by_org.fetch(org_uuid, []); end
    def conversation(_org_uuid, conv_uuid); @details_by_uuid.fetch(conv_uuid); end
  end

  def ts(offset = 0)
    (Time.current + offset).iso8601(6)
  end

  setup do
    @orgs = [ { "uuid" => "ORG1", "name" => "Edwin" } ]
    @convs = {
      "ORG1" => [
        { "uuid" => "CONV1", "name" => "Chat A", "created_at" => ts(-3600), "updated_at" => ts(-60) }
      ]
    }
    @details = {
      "CONV1" => {
        "uuid" => "CONV1",
        "name" => "Chat A",
        "created_at" => ts(-3600),
        "updated_at" => ts(-60),
        "chat_messages" => [
          { "uuid" => "M1", "sender" => "human", "text" => "hello",
            "created_at" => ts(-3500), "content" => [ { "type" => "text", "text" => "hello" } ] },
          { "uuid" => "M2", "sender" => "assistant", "text" => "hi",
            "created_at" => ts(-3400), "content" => [ { "type" => "text", "text" => "hi friend" } ] }
        ]
      }
    }
  end

  test "creates a desktop project, conversation, and messages" do
    client = FakeClient.new(orgs: @orgs, convs_by_org: @convs, details_by_uuid: @details)
    summary = ClaudeDesktop::Importer.new(client: client, logger: Logger.new(IO::NULL)).run

    assert_equal 1, summary.organizations
    assert_equal 1, summary.conversations_seen
    assert_equal 1, summary.created

    project = Project.find_by(path: "claude-desktop:ORG1")
    assert_not_nil project
    assert_match(/Claude Desktop/, project.name)

    conv = Conversation.find_by(session_id: "CONV1")
    assert_equal "desktop", conv.source
    assert conv.desktop?
    assert_equal "Chat A", conv.title
    assert_equal 2, conv.message_count
    assert_equal 2, conv.messages.count
    assert_equal %w[user assistant], conv.messages.order(:position).map(&:role)
  end

  test "re-import skips unchanged conversations" do
    client = FakeClient.new(orgs: @orgs, convs_by_org: @convs, details_by_uuid: @details)
    ClaudeDesktop::Importer.new(client: client, logger: Logger.new(IO::NULL)).run

    summary = ClaudeDesktop::Importer.new(client: client, logger: Logger.new(IO::NULL)).run
    assert_equal 1, summary.skipped
    assert_equal 0, summary.created
    assert_equal 0, summary.updated
  end

  test "re-import updates when updated_at advances" do
    client = FakeClient.new(orgs: @orgs, convs_by_org: @convs, details_by_uuid: @details)
    ClaudeDesktop::Importer.new(client: client, logger: Logger.new(IO::NULL)).run

    @convs["ORG1"][0]["updated_at"] = ts(0)
    @details["CONV1"]["updated_at"] = ts(0)
    @details["CONV1"]["chat_messages"] << { "uuid" => "M3", "sender" => "human",
                                             "text" => "follow up", "created_at" => ts(-1),
                                             "content" => [ { "type" => "text", "text" => "follow up" } ] }

    summary = ClaudeDesktop::Importer.new(client: client, logger: Logger.new(IO::NULL)).run
    assert_equal 1, summary.updated

    conv = Conversation.find_by(session_id: "CONV1")
    assert_equal 3, conv.message_count
  end

  test "does not resurrect a soft-deleted desktop conversation" do
    client = FakeClient.new(orgs: @orgs, convs_by_org: @convs, details_by_uuid: @details)
    ClaudeDesktop::Importer.new(client: client, logger: Logger.new(IO::NULL)).run
    conv = Conversation.find_by(session_id: "CONV1")
    conv.soft_delete!

    @details["CONV1"]["updated_at"] = ts(0)
    summary = ClaudeDesktop::Importer.new(client: client, logger: Logger.new(IO::NULL)).run
    assert_equal 1, summary.skipped
    assert_nil Conversation.find_by(session_id: "CONV1")
    assert Conversation.with_deleted.exists?(session_id: "CONV1")
  end

  test "continues when one conversation detail fails" do
    client = Object.new
    def client.organizations; [ { "uuid" => "O" } ]; end
    def client.conversations(_); [
      { "uuid" => "good", "updated_at" => nil },
      { "uuid" => "bad",  "updated_at" => nil }
    ]; end
    def client.conversation(_, uuid)
      raise ClaudeDesktop::Client::Error, "boom" if uuid == "bad"
      { "uuid" => uuid, "name" => "ok", "created_at" => Time.current.iso8601, "updated_at" => Time.current.iso8601, "chat_messages" => [] }
    end

    summary = ClaudeDesktop::Importer.new(client: client, logger: Logger.new(IO::NULL)).run
    assert_equal 1, summary.created
    assert_equal 1, summary.errors
  end
end
