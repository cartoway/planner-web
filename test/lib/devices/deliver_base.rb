module DeliverBase

  def set_route
    planning = plannings(:planning_one)
    planning.update!(date: 10.days.from_now)
    planning.routes.select(&:vehicle_usage_id).each do |route|
      route.update!(end: (route.start || 0) + 1.hour)
    end

    @route = routes(:route_one_one)
    @vehicle = @route.vehicle_usage.vehicle
  end
end
