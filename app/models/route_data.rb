class RouteData < ApplicationRecord
  include QuantityAttr
  quantity_attr :pickups, :deliveries

  include LocalizedAttr

  attr_localized :pickups
  attr_localized :deliveries

  include TimeAttr
  attribute :start, ScheduleType.new
  attribute :end, ScheduleType.new
  attribute :departure, ScheduleType.new
  time_attr :start, :end, :departure

  def duration
    self.visits_duration.to_i + self.wait_time.to_i + self.drive_time.to_i
  end
end
