require "test_helper"
require "tmpdir"

class SessionForksControllerTest < ActionDispatch::IntegrationTest
  test "create responds with a turbo stream containing the resume command" do
    Dir.mktmpdir do |dir|
      session_id = SecureRandom.uuid
      path = File.join(dir, "#{session_id}.jsonl")
      File.write(path, { "type" => "user", "uuid" => "u1", "parentUuid" => nil, "sessionId" => session_id,
                         "message" => { "role" => "user", "content" => "hi" } }.to_json + "\n")
      conversation = make_conversation(session_id: session_id, file_path: path)

      post conversation_forks_path(conversation, message_uuid: "u1"),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      assert_response :success
      fork = SessionFork.last
      assert_match(/fork-slot-u1/, response.body)
      assert_match(/claude --resume #{fork.session_id} --fork-session/, response.body)
    end
  end

  test "create shows the error when the session file is missing" do
    conversation = make_conversation(file_path: "/nonexistent/x.jsonl")
    post conversation_forks_path(conversation, message_uuid: "u1"),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match(/Session file not found/, response.body)
    assert_equal 0, SessionFork.count
  end
end
