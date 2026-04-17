class Project < ApplicationRecord
  has_many :conversations, dependent: :destroy

  validates :path, presence: true, uniqueness: true
  validates :name, presence: true

  scope :recent, -> { order(Arel.sql("last_activity_at IS NULL, last_activity_at DESC")) }

  def self.find_or_create_for_cwd(cwd)
    find_or_create_by(path: cwd) do |project|
      project.name = File.basename(cwd)
    end
  end

  def refresh_counters!
    update!(
      conversation_count: conversations.count,
      last_activity_at: conversations.maximum(:last_activity_at)
    )
  end
end
