class AddUserAgentToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :claude_ai_user_agent, :string
  end
end
