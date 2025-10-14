class V100::Entities::Stop < V100::Entities::StopStatus
  def self.entity_name
    'V100_Stop'
  end

  STOP_TYPES = {
    StopVisit: 'visit',
    StopStore: 'store',
    StopRest: 'rest'
  }.freeze

  expose(:destination_ref, documentation: { type: String }) { |stop|
    if stop.is_a?(StopVisit) && stop.visit && stop.visit.destination
      stop.visit.destination.ref
    end
  }
  expose(:store_ref, documentation: { type: String }) { |stop|
    if stop.is_a?(StopStore) && stop.store
      stop.store.ref
    end
  }
  expose(:visit_ref, documentation: { type: String }) { |stop|
    if stop.is_a?(StopVisit) && stop.visit
      stop.visit.ref
    end
  }
  expose(:stop_type, documentation: { type: String }) { |stop|
    STOP_TYPES[stop.class.name.to_sym]
  }
  expose(:active, documentation: { type: 'Boolean' })
  expose(:distance, documentation: { type: Float, desc: 'Distance between the stop and previous one.' })
  expose(:drive_time, documentation: { type: Integer, desc: 'Time in seconds between the stop and previous one.' })
  expose(:visit_id, documentation: { type: Integer })
  expose(:route_id, documentation: { type: Integer }) { |stop|
    stop.route_id
  }
  expose(:planning_id, documentation: { type: Integer }) { |stop|
    stop.route.planning_id
  }
  expose(:wait_time, documentation: { type: DateTime, desc: 'Time before delivery.' }) { |m| m.wait_time && ('%i:%02i:%02i' % [m.wait_time / 60 / 60, m.wait_time / 60 % 60, m.wait_time % 60]) }
  expose(:time, documentation: { type: DateTime, desc: 'Arrival planned at.' }) { |m|
    (m.route.planning.date || Time.zone.today).beginning_of_day + m.time if m.time
  }
  expose(:out_of_window, documentation: { type: 'Boolean' })
  expose(:out_of_capacity, documentation: { type: 'Boolean' })
  expose(:out_of_drive_time, documentation: { type: 'Boolean' })
  expose(:out_of_force_position, documentation: { type: 'Boolean' })
  expose(:out_of_work_time, documentation: { type: 'Boolean' })
  expose(:out_of_max_distance, documentation: { type: 'Boolean' })
  expose(:out_of_max_ride_distance, documentation: { type: 'Boolean' })
  expose(:out_of_max_ride_duration, documentation: { type: 'Boolean' })
  expose(:out_of_max_reload, documentation: { type: 'Boolean' })
  expose(:out_of_relation, documentation: { type: 'Boolean' })
  expose(:custom_attributes_typed_hash, documentation: {type: Hash, desc: 'Additional properties'}, as: :custom_attributes)
end
