class ConversationLabel < ApplicationRecord
  belongs_to :conversation
  belongs_to :label

  validates :conversation_id, uniqueness: { scope: :label_id }
end
