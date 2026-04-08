# frozen_string_literal: true

# Creates `roles` (permissions: operations + forms only), adds JSONB preferences on `users`.
# Header layout preferences (headers) are stored on `users` only.
class RolesAndUserPreferences < ActiveRecord::Migration[6.1]
  def up
    if !table_exists?(:roles)
      create_table :roles do |t|
        t.references :reseller, null: false, foreign_key: true
        t.string :name, null: false
        t.string :ref
        t.string :icon
        t.string :color
        t.jsonb :operations, null: false, default: {}
        t.jsonb :forms, null: false, default: {}
        t.timestamps
      end

      add_index :roles, %i[reseller_id ref], unique: true, where: 'ref IS NOT NULL'
      add_reference :users, :role, foreign_key: { on_delete: :nullify }
    end

    add_column :users, :headers, :jsonb, null: false, default: {} unless column_exists?(:users, :headers)
  end

  def down
    remove_column :users, :headers if column_exists?(:users, :headers)
    remove_reference :users, :role, foreign_key: true if column_exists?(:users, :role_id)

    return unless table_exists?(:roles)

    drop_table :roles if table_exists?(:roles)
  end
end
