class CreateSubagents < ActiveRecord::Migration[8.1]
  def change
    create_table :subagents do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :agent_id, null: false
      t.string :agent_type
      t.string :description
      t.string :tool_use_id
      t.string :file_path, null: false
      t.datetime :file_mtime
      t.integer :file_size
      t.datetime :started_at
      t.datetime :last_activity_at
      t.integer :message_count, null: false, default: 0
      t.timestamps
    end
    add_index :subagents, :file_path, unique: true
    add_index :subagents, [ :conversation_id, :agent_id ], unique: true
    add_index :subagents, :tool_use_id

    # No DB-level foreign key: on SQLite that rebuilds the messages table,
    # which silently drops the FTS5 sync triggers on it.
    add_column :messages, :subagent_id, :integer
    add_index :messages, :subagent_id
  end
end
