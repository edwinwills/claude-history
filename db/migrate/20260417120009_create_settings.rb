class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :claude_ai_session_key
      t.timestamps
    end
  end
end
