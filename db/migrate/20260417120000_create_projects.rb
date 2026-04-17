class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :path, null: false
      t.string :name, null: false
      t.datetime :last_activity_at
      t.integer :conversation_count, null: false, default: 0

      t.timestamps
    end

    add_index :projects, :path, unique: true
    add_index :projects, :last_activity_at
  end
end
