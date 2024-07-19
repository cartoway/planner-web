module IcalendarUrlHelper
  def api_plannings_calendar_path(query)
    Addressable::Template.new('/api/0.1/plannings.ics{?query*}').expand(query: query).to_s
  end

  def api_planning_calendar_path(planning, query)
    Addressable::Template.new('/api/0.1/plannings/%s.ics{?query*}' % [
      planning.ref ? URI::DEFAULT_PARSER.escape("ref:#{planning.ref}") : planning.id
    ]).expand(query: query).to_s
  end

  def api_route_calendar_path(route, query)
    Addressable::Template.new('/api/0.1/plannings/%s/routes/%s.ics{?query*}' % [
      route.planning.ref ? URI::DEFAULT_PARSER.escape("ref:#{route.planning.ref}") : route.planning.id,
      route.ref ? URI::DEFAULT_PARSER.escape("ref:#{route.ref}") : route.id
    ]).expand(query: query).to_s
  end
end
