class V100::Entities::VehicleUsage < Grape::Entity
  def self.entity_name
    'V100_VehicleUsage'
  end

  expose(:id, documentation: { type: Integer })
  expose(:vehicle_usage_set_id, documentation: { type: Integer })
  expose(:time_window_start, documentation: { type: DateTime }) { |m| m.time_window_start_absolute_time_with_seconds }
  expose(:time_window_end, documentation: { type: DateTime }) { |m| m.time_window_end_absolute_time_with_seconds }
  expose(:store_start_id, documentation: { type: Integer })
  expose(:store_stop_id, documentation: { type: Integer })
  expose(:store_duration, documentation: { type: DateTime }) { |m| m.store_duration_absolute_time_with_seconds }
  expose(:service_time_start, documentation: { type: DateTime }) { |m| m.service_time_start_absolute_time_with_seconds }
  expose(:service_time_end, documentation: { type: DateTime }) { |m| m.service_time_end_absolute_time_with_seconds }
  expose(:work_time, documentation: { type: DateTime }) { |m| m.work_time_absolute_time_with_seconds }
  expose(:rest_start, documentation: { type: DateTime }) { |m| m.rest_start_absolute_time_with_seconds }
  expose(:rest_stop, documentation: { type: DateTime }) { |m| m.rest_stop_absolute_time_with_seconds }
  expose(:rest_duration, documentation: { type: DateTime }) { |m| m.rest_duration_absolute_time_with_seconds }
  expose(:store_rest_id, documentation: { type: Integer })
  expose(:active, documentation: { type: 'Boolean' })
  expose(:tag_ids, documentation: { type: Integer, is_array: true })

  # Deprecated fields
  expose(:open, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `visit_duration` instead' }) { |m| m.time_window_start_absolute_time_with_seconds }
  expose(:close, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_end` instead.' }) { |m| m.time_window_end_absolute_time_with_seconds }
end
