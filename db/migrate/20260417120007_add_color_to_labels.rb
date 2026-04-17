class AddColorToLabels < ActiveRecord::Migration[8.1]
  def change
    add_column :labels, :color, :string, null: false, default: "#475569"
  end
end
