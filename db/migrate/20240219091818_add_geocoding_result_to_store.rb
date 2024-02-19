class AddGeocodingResultToStore < ActiveRecord::Migration
  def up
    add_column :stores, :geocoding_result, :jsonb, null: false, default: {}, using: 'CAST(geocoding_result AS JSON)'
  end

  def down
    remove_column :stores, :geocoding_result
  end
end
