class Project < ApplicationRecord
  has_many :conversations, dependent: :destroy

  default_scope { where(deleted_at: nil) }

  validates :path, presence: true, uniqueness: true
  validates :name, presence: true

  scope :recent, -> { order(Arel.sql("last_activity_at IS NULL, last_activity_at DESC")) }
  scope :code, -> { where.not("path LIKE ?", "claude-desktop%") }
  scope :desktop, -> { where("path LIKE ?", "claude-desktop%") }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :deleted, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }

  def self.find_or_create_for_cwd(cwd)
    find_or_create_by(path: cwd) do |project|
      project.name = File.basename(cwd)
    end
  end

  # Projects from desktop imports all live under a synthetic path that starts
  # with "claude-desktop" — see ClaudeDesktopExport::Importer::PROJECT_PATH.
  # Everything else is a real filesystem path from Claude Code.
  def desktop?
    path.to_s.start_with?("claude-desktop")
  end

  def code?
    !desktop?
  end

  def source
    desktop? ? "desktop" : "code"
  end

  def refresh_counters!
    update!(
      conversation_count: conversations.count,
      last_activity_at: conversations.maximum(:last_activity_at)
    )
  end

  def deleted?
    deleted_at.present?
  end

  # Soft-delete the project and cascade to its active conversations using the
  # same timestamp so restore! can distinguish batch-with-project vs
  # individually-deleted ones.
  def soft_delete!
    ts = Time.current
    conversations.update_all(deleted_at: ts)
    update!(deleted_at: ts)
  end

  # Restore the project and re-activate only the conversations that were
  # soft-deleted as part of the same batch (matching deleted_at). Conversations
  # that were individually deleted before the project was trashed stay in
  # their own trash.
  def restore!
    batch_ts = deleted_at
    transaction do
      if batch_ts
        Conversation.with_deleted.where(project_id: id, deleted_at: batch_ts).update_all(deleted_at: nil)
      end
      update!(deleted_at: nil)
    end
  end
end
