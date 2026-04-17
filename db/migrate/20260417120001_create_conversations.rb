class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :project, null: false, foreign_key: true
      t.string :session_id, null: false
      t.string :file_path, null: false
      t.datetime :file_mtime
      t.integer :file_size
      t.string :slug
      t.string :title
      t.datetime :started_at
      t.datetime :last_activity_at
      t.integer :message_count, null: false, default: 0
      t.string :git_branch
      t.string :cwd

      t.timestamps
    end

    add_index :conversations, :session_id, unique: true
    add_index :conversations, :file_path, unique: true
    add_index :conversations, :last_activity_at
  end
end
