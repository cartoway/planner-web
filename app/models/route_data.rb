class RouteData < ApplicationRecord
  nilify_blanks

  include QuantityAttr
  quantity_attr :pickups, :deliveries

  attribute :hidden, :boolean, default: false
  attribute :size_active, :integer, default: 0
  attribute :size_destinations, :integer, default: 0
  attribute :size_store_reloads, :integer, default: 0
  attribute :stops_size, :integer, default: 0
  attribute :size_active_destinations, :integer, default: 0
  attribute :no_geolocalization, :boolean, default: false
  attribute :no_path, :boolean, default: false
  attribute :out_of_capacity, :boolean, default: false
  attribute :out_of_drive_time, :boolean, default: false
  attribute :out_of_force_position, :boolean, default: false
  attribute :out_of_max_distance, :boolean, default: false
  attribute :out_of_max_reload, :boolean, default: false
  attribute :out_of_max_ride_distance, :boolean, default: false
  attribute :out_of_max_ride_duration, :boolean, default: false
  attribute :out_of_relation, :boolean, default: false
  attribute :out_of_skill, :boolean, default: false
  attribute :out_of_window, :boolean, default: false
  attribute :out_of_work_time, :boolean, default: false
  attribute :unmanageable_capacity, :boolean, default: false
  attribute :max_loads, default: {}

  include LocalizedAttr

  attr_localized :pickups
  attr_localized :deliveries

  include TimeAttr
  attribute :start, ScheduleType.new
  attribute :end, ScheduleType.new
  attribute :departure, ScheduleType.new
  time_attr :start, :end, :departure

  def duration
    # /!\ Duration without service times !
    work_duration + self.rests_duration.to_i
  end

  def work_duration
    # /!\ Duration without service times !
    self.visits_duration.to_i + self.wait_time.to_i + self.drive_time.to_i
  end

  def import_attributes
    super.tap do |attrs|
      attrs.each do |key, value|
        next unless value.nil?

        default = self.class._default_attributes[key]
        attrs[key] = default.value unless default.nil?
      end
    end
  end
end
