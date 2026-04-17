class Project < ApplicationRecord
  has_many :conversations, dependent: :destroy

  validates :path, presence: true, uniqueness: true
  validates :name, presence: true

  scope :recent, -> { order(Arel.sql("last_activity_at IS NULL, last_activity_at DESC")) }
  scope :code, -> { where.not("path LIKE ?", "claude-desktop%") }
  scope :desktop, -> { where("path LIKE ?", "claude-desktop%") }

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
end
