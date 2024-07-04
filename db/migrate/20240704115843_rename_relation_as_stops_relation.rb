class RenameRelationAsStopsRelation < ActiveRecord::Migration[5.2]
  def up
    rename_index :relations, :index_relations_on_customer_id_and_current_id_and_successor_id, :index_relations_customer_current_successord_id
    rename_table :relations, :stops_relations
  end

  def down
    rename_table :stops_relations, :relations
    rename_index :relations, :index_relations_customer_current_successord_id, :index_relations_on_customer_id_and_current_id_and_successor_id
  end
end
