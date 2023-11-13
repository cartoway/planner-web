class CreateCustomAttributes < ActiveRecord::Migration
  def change
    add_column :vehicles, :custom_attributes, :jsonb, null: false, default: {}

    create_table :custom_attributes do |t|
      t.string :name
      t.integer :object_type, null: false, default: 0
      t.integer :object_class, null: false, default: 0
      t.string :default_value
      t.text :description
      t.references :customer, index: true

      t.timestamps
    end
  end
end
