class PlanningAutomaticInsertService
  def initialize(planning, stops, options = {})
    @planning = planning
    @stops = Array(stops).compact
    @options = { exclusion: :locked }.merge(options)
  end

  def call
    impacted_routes = []

    @stops.each do |stop|
      route = @planning.automatic_insert(stop, @options) || raise(Exceptions::LoopError.new)
      route.reset_traces!
      impacted_routes << route
    end

    impacted_routes.compact.uniq
  end
end
