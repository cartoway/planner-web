class StopStore < Stop
  delegate :lat,
           :lng,
           :name,
           :street,
           :postalcode,
           :city,
           :state,
           :country,
           :color,
           :icon,
           :icon_size,
           :default_icon,
           :default_icon_size,
           to: :store

  validates :store, presence: true

  def ref
    store.ref
  end

  def position?
    store.lat.present? && store.lng.present?
  end

  def position
    store
  end

  def detail
    nil
  end

  def comment
    nil
  end

  def phone_number
    nil
  end

  def duration
    route.vehicle_usage.default_store_duration || 0
  end

  def duration_time_with_seconds
    route.vehicle_usage.default_store_duration_time_with_seconds
  end

  def destination_duration
    0 # TODO: Add store service duration
  end

  def destination_duration_time_with_seconds
    0 # TODO: Add store service duration
  end

  def base_id
    "d#{store.id}"
  end

  def base_updated_at
    store.updated_at
  end

  def priority
    nil
  end

  def force_position
    nil
  end

  def to_s
    "#{active ? 'x' : '_'} #{store.name}"
  end

  def time_window_start_1
    route.vehicle_usage.default_time_window_start
  end

  def time_window_start_1_time
    route.vehicle_usage.default_time_window_start_time
  end

  def time_window_start_1_absolute_time
    route.vehicle_usage.default_time_window_start_absolute_time
  end

  def time_window_end_1
    route.vehicle_usage.default_time_window_end
  end

  def time_window_end_1_time
    route.vehicle_usage.default_time_window_end_time
  end

  def time_window_end_1_absolute_time
    route.vehicle_usage.default_time_window_end_absolute_time
  end

  def time_window_start_2
    nil
  end

  def time_window_start_2_time
    nil
  end

  def time_window_end_2
    nil
  end

  def time_window_end_2_time
    nil
  end
end
