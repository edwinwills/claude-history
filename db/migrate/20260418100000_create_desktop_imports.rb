class CreateDesktopImports < ActiveRecord::Migration[8.1]
  def change
    create_table :desktop_imports do |t|
      t.integer :conversations_seen, null: false, default: 0
      t.integer :conversations_created, null: false, default: 0
      t.integer :conversations_updated, null: false, default: 0
      t.integer :conversations_skipped, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.text :error_detail
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :desktop_imports, :created_at
  end
end
