class AddSourceToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :source, :string, null: false, default: "code"
    add_index :conversations, :source
  end
end
