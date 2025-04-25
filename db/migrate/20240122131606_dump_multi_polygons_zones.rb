class DumpMultiPolygonsZones < ActiveRecord::Migration
  def up
    Zoning.find_each{ |zoning|
      SimplifyGeometry.dump_multipolygons(zoning)
    }
  end
end
