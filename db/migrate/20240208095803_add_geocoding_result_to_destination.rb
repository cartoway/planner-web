class AddGeocodingResultToDestination < ActiveRecord::Migration
  def up
    add_column :destinations, :geocoding_result, :jsonb, null: false, default: {}, using: 'CAST(geocoding_result AS JSON)'
  end

  def down
    remove_column :destinations, :geocoding_result
  end
end
