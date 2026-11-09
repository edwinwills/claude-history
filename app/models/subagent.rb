# A subagent spawned from a Claude Code session (Agent/Task tool). Its
# transcript lives in <project>/<session_id>/subagents/agent-<id>.jsonl and its
# messages are stored under the parent conversation with subagent_id set.
class Subagent < ApplicationRecord
  belongs_to :conversation
  has_many :messages, -> { order(:position) }, dependent: :delete_all

  validates :agent_id, presence: true
  validates :file_path, presence: true, uniqueness: true

  def display_type
    agent_type.presence || "general-purpose"
  end

  def display_title
    description.presence || "#{display_type} agent #{agent_id.to_s[0, 8]}"
  end

  def display_messages
    messages.where(record_type: %w[user assistant])
  end
end
