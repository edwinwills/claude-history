# A truncated copy of a Claude Code session, written next to the original
# JSONL, that `claude --resume <session_id> --fork-session` can pick up from.
# The importer skips these files so they don't show up as duplicate sessions.
class SessionFork < ApplicationRecord
  belongs_to :conversation, -> { with_deleted }

  validates :session_id, presence: true, uniqueness: true
  validates :message_uuid, :file_path, presence: true

  def resume_command
    "cd #{Shellwords.escape(conversation.cwd.to_s)} && claude --resume #{session_id} --fork-session"
  end
end
