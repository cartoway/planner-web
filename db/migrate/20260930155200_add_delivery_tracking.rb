# frozen_string_literal: true

class AddDeliveryTracking < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :company_logo, :string unless column_exists?(:customers, :company_logo)
    if column_exists?(:customers, :email_template) && !column_exists?(:customers, :recipient_template)
      rename_column :customers, :email_template, :recipient_template
    elsif !column_exists?(:customers, :recipient_template)
      add_column :customers, :recipient_template, :text
    end

    return if table_exists?(:operation_delivery_trackings)

    create_table :operation_delivery_trackings, id: :serial do |t|
      t.references :operation, type: :integer, null: false, foreign_key: { on_delete: :cascade }, index: false
      # Frozen destination id from publish — no FK: destinations/planning may disappear after launch.
      t.integer :destination_id, null: false
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.timestamps null: false
    end

    add_index :operation_delivery_trackings, :token, unique: true, name: 'index_operation_delivery_trackings_on_token'
    add_index :operation_delivery_trackings, [:operation_id, :destination_id],
              unique: true, name: 'index_operation_delivery_trackings_on_operation_and_destination'
    add_index :operation_delivery_trackings, :destination_id, name: 'index_operation_delivery_trackings_on_destination_id'
    add_index :operation_delivery_trackings, :operation_id, name: 'index_operation_delivery_trackings_on_operation_id'
  end
end
