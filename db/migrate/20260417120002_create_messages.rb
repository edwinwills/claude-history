class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :uuid
      t.string :parent_uuid
      t.string :record_type, null: false
      t.string :role
      t.text :text_content
      t.text :raw
      t.datetime :timestamp
      t.integer :position, null: false

      t.timestamps
    end

    add_index :messages, [ :conversation_id, :position ]
    add_index :messages, [ :conversation_id, :uuid ]
    add_index :messages, :record_type
  end
end
