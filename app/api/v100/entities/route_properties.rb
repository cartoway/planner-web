class V100::Entities::RouteProperties < Grape::Entity
  def self.entity_name
    'V100_RouteProperties'
  end

  expose(:id, documentation: { type: Integer })
  expose(:vehicle_usage_id, documentation: { type: Integer })
  expose(:start, documentation: { type: DateTime }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.start if m.start
  }
  expose(:end, documentation: { type: DateTime }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.end if m.end
  }
  expose(:hidden, documentation: { type: 'Boolean' })
  expose(:locked, documentation: { type: 'Boolean' })
  expose(:color, documentation: { type: String, desc: 'Color code with #. For instance: #FF0000.' })
  expose(:geojson, documentation: { type: String, desc: 'Geojson string of track and stops of the route. Default empty, set parameter geojson=true|point|polyline to get this extra content.' }) { |m, options|
    if options[:geojson] && options[:geojson] != :false
      m.to_geojson(true, true,
        if options[:geojson] == :polyline
          :polyline
        elsif options[:geojson] == :point
          false
        else
          true
        end)
    end
  }
end
