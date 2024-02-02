class AddRelationsTable < ActiveRecord::Migration
  def up
    create_table :relations do |t|
      t.integer :relation_type, null: false, default: 0
      t.references :customer
      t.references :current
      t.references :successor
      t.index [:customer_id, :current_id, :successor_id]

      t.foreign_key :visits, column: :current_id, primary_key: 'id', on_delete: :cascade
      t.foreign_key :visits, column: :successor_id, primary_key: 'id', on_delete: :cascade

      t.timestamps
    end

    add_column :stops, :out_of_relation, :boolean, default: false
  end

  def down
    drop_table :relations

    remove_column :stops, :out_of_relation
  end
end
