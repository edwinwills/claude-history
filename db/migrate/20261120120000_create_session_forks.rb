class CreateSessionForks < ActiveRecord::Migration[8.1]
  def change
    create_table :session_forks do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :message_uuid, null: false
      t.string :session_id, null: false
      t.string :file_path, null: false
      t.timestamps
    end
    add_index :session_forks, :session_id, unique: true
  end
end
