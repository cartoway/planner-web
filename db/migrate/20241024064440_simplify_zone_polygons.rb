class SimplifyZonePolygons < ActiveRecord::Migration[6.1]
  def up
    Zone.find_each{ |zone|
      next if zone.polygon.nil? || JSON.parse(zone.polygon)['geometry'].nil?

      zone.validate
      zone.save! unless zone.destroyed?
    }
  end
end
