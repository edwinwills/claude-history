class AddCustomTitleToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :custom_title, :string
  end
end
