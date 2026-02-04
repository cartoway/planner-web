class AddRelatedFieldToCustomAttributes < ActiveRecord::Migration[6.1]
  def up
    add_column :custom_attributes, :related_field, :string
    add_column :routes, :custom_attributes, :jsonb, null: false, default: {}

    # Remove duplicates
    execute <<~SQL.squish
      WITH duplicates AS (
        SELECT
          MIN(id) AS keep_id,
          ARRAY_AGG(id) AS ids
        FROM custom_attributes
        WHERE related_field IS NULL
        GROUP BY customer_id, object_class, name
        HAVING COUNT(*) > 1
      )
      DELETE FROM custom_attributes
      WHERE id IN (
        SELECT UNNEST(ids[2:]) FROM duplicates
      );
    SQL

    # Add index for uniqueness when related_field is present
    add_index :custom_attributes, [:customer_id, :object_class, :related_field, :name],
              name: 'idx_ca_on_customer_obj_class_rel_field_name',
              unique: true,
              where: 'related_field IS NOT NULL'

    # Add index for uniqueness when related_field is NULL (existing behavior)
    add_index :custom_attributes, [:customer_id, :object_class, :name],
              name: 'idx_ca_on_customer_obj_class_name',
              unique: true,
              where: 'related_field IS NULL'
  end

  def down
    remove_index :custom_attributes, name: 'idx_ca_on_customer_obj_class_rel_field_name'
    remove_index :custom_attributes, name: 'idx_ca_on_customer_obj_class_name'

    remove_column :routes, :custom_attributes
    remove_column :custom_attributes, :related_field
  end
end
