ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # SQLite + FTS triggers don't play well with parallel workers — single process is plenty fast here.
    parallelize(workers: 1)

    fixtures :all

    def make_project(path: "/Users/edwin/code/example")
      Project.find_or_create_for_cwd(path)
    end

    def make_conversation(project: nil, session_id: SecureRandom.uuid, file_path: nil, **attrs)
      project ||= make_project
      Conversation.create!({
        project: project,
        session_id: session_id,
        file_path: file_path || "/tmp/#{session_id}.jsonl",
        started_at: Time.current,
        last_activity_at: Time.current,
        message_count: 0,
        cwd: project.path
      }.merge(attrs))
    end
  end
end
