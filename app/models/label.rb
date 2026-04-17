class Label < ApplicationRecord
  has_many :conversation_labels, dependent: :destroy
  has_many :conversations, through: :conversation_labels

  normalizes :name, with: ->(n) { n.to_s.strip }

  validates :name, presence: true, length: { maximum: 60 }
  validates :name, uniqueness: { case_sensitive: false }

  scope :alphabetical, -> { order(Arel.sql("LOWER(name) ASC")) }

  COLOR_CLASSES = %w[primary secondary accent info success warning error neutral].freeze

  def self.find_or_create_by_name!(name)
    normalized = name.to_s.strip
    return nil if normalized.empty?
    where("LOWER(name) = ?", normalized.downcase).first || create!(name: normalized)
  end

  def color_class
    COLOR_CLASSES[(Digest::MD5.hexdigest(name.downcase).to_i(16) % COLOR_CLASSES.size)]
  end
end
