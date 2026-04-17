class AddLabels < ActiveRecord::Migration[8.1]
  def change
    create_table :labels do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :labels, "LOWER(name)", unique: true, name: "index_labels_on_lower_name"

    create_table :conversation_labels do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true
      t.timestamps
    end
    add_index :conversation_labels, [ :conversation_id, :label_id ], unique: true
  end
end
