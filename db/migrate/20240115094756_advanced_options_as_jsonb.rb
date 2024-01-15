class AdvancedOptionsAsJsonb < ActiveRecord::Migration
  def up
    change_column :customers, :advanced_options, :jsonb, null: false, default: {}, using: 'CAST(advanced_options AS JSON)'
  end

  def down
    change_column :customers, :advanced_options, :text
  end
end
