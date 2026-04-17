class Label < ApplicationRecord
  has_many :conversation_labels, dependent: :destroy
  has_many :conversations, through: :conversation_labels

  PALETTE = %w[
    #475569
    #dc2626
    #ea580c
    #d97706
    #ca8a04
    #16a34a
    #0d9488
    #2563eb
    #7c3aed
    #9333ea
    #db2777
  ].freeze

  DEFAULT_COLOR = "#475569"

  normalizes :name, with: ->(n) { n.to_s.strip }

  validates :name, presence: true, length: { maximum: 60 }
  validates :name, uniqueness: { case_sensitive: false }
  validates :color, presence: true, inclusion: { in: PALETTE }

  scope :alphabetical, -> { order(Arel.sql("LOWER(name) ASC")) }

  def self.find_or_create_by_name!(name)
    normalized = name.to_s.strip
    return nil if normalized.empty?
    where("LOWER(name) = ?", normalized.downcase).first || create!(name: normalized, color: DEFAULT_COLOR)
  end

  def color_with_default
    PALETTE.include?(color) ? color : DEFAULT_COLOR
  end
end
