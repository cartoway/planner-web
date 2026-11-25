# Assigns visits to routes from planning zonings.
# - visits_free Array: initial split (append via add_visits, Zoning#apply order kept)
# - visits_free nil/false: re-apply (keep same-route order + active; newcomers by visit.id)
class PlanningSplitByZonesService
  def initialize(planning)
    @planning = planning
  end

  # @return [Boolean] true when zoning was applied
  def call(visits_free)
    return false unless applicable?

    vehicles_map = build_vehicles_map
    unplanned = @planning.routes.find{ |route| !route.vehicle_usage? }
    return false unless unplanned

    # Directly assigning zones to a new zoning updates their zoning_id
    collect_zones = @planning.zonings.flat_map{ |zoning| zoning.zones.map(&:dup) }

    if visits_free
      apply_initial(map_visits_to_routes(visits_free, collect_zones, vehicles_map, unplanned))
    else
      stop_visits = unlocked_stop_visits
      visit_to_route = map_visits_to_routes(stop_visits.map(&:visit).uniq, collect_zones, vehicles_map, unplanned)
      apply_reapply(visit_to_route, stop_visits, unplanned)
    end
    true
  end

  private

  def applicable?
    return false if @planning.zonings.empty? || @planning.routes.empty?

    @planning.zonings.any?{ |zoning|
      zoning.zones.any?{ |zone| !zone.avoid_zone && !zone.vehicle_id.blank? }
    }
  end

  def build_vehicles_map
    Hash[@planning.routes.group_by(&:vehicle_usage).map{ |vehicle_usage, vu_routes|
      next if vehicle_usage && !vehicle_usage.active?

      [vehicle_usage && vehicle_usage.vehicle, vu_routes[0]]
    }]
  end

  def unlocked_stop_visits
    @planning.routes.reject(&:locked).flat_map{ |route|
      route.stops.select{ |stop| stop.is_a?(StopVisit) }
    }
  end

  def map_visits_to_routes(visits, collect_zones, vehicles_map, unplanned)
    visit_to_route = {}
    Zoning.new(zones: collect_zones).apply(visits).each{ |zone, zone_visits|
      route =
        if zone && zone.vehicle && vehicles_map[zone.vehicle] && !vehicles_map[zone.vehicle].locked
          vehicles_map[zone.vehicle]
        else
          # Unplanned also receives visits when locked (append-only in apply_reapply)
          unplanned
        end
      zone_visits.each{ |visit| visit_to_route[visit] = route }
    }
    visit_to_route
  end

  def apply_initial(visit_to_route)
    routes_visits = {}
    visit_to_route.each{ |visit, route|
      (routes_visits[route] ||= []) << [visit, true]
    }

    touched = []
    Route.transaction do
      routes_visits.each{ |route, visits|
        route.add_visits(visits, false)
        touched << route
      }
      compute_touched!(touched)
    end
  end

  # Kept: current index order + active. Newcomers: append sorted by visit.id.
  # Locked unplanned: append only visits not already on that route.
  def apply_reapply(visit_to_route, stop_visits, unplanned)
    routes_visits = {}
    kept_ids = Set.new

    stop_visits.each{ |stop|
      next unless visit_to_route[stop.visit] == stop.route
      next if kept_ids.include?(stop.visit_id)

      kept_ids << stop.visit_id
      (routes_visits[stop.route] ||= []) << [stop.visit, stop.active]
    }

    # Visits already on locked unplanned stay put; only real newcomers are appended
    if unplanned.locked
      unplanned.stops.select{ |stop| stop.is_a?(StopVisit) }.each{ |stop|
        next unless visit_to_route[stop.visit] == unplanned

        kept_ids << stop.visit_id
      }
    end

    newcomers_by_route = {}
    visit_to_route.each{ |visit, route|
      next if kept_ids.include?(visit.id)

      (newcomers_by_route[route] ||= []) << visit
    }
    newcomers_by_route.each{ |route, visits|
      (routes_visits[route] ||= []).concat(visits.sort_by(&:id).map{ |visit| [visit, true] })
    }

    touched = []
    Route.transaction do
      @planning.routes.reject(&:locked).each{ |route|
        desired = routes_visits.fetch(route, [])
        current = route.stops.select{ |stop| stop.is_a?(StopVisit) }.map{ |stop| [stop.visit_id, stop.active] }
        next if current == desired.map{ |visit, active| [visit.id, active] }

        # recompute deferred until all routes rewritten (no mid-move duplicate visit_ids)
        route.set_visits(desired, false)
        touched << route
      }

      if unplanned.locked && (newcomers = routes_visits[unplanned]).present?
        unplanned.add_visits(newcomers, false)
        touched << unplanned
      end

      compute_touched!(touched)
    end
  end

  def compute_touched!(touched)
    touched.select(&:vehicle_usage?).each{ |route|
      # Stop belongs_to :route, touch: true bumps lock_version during set_visits/add_visits
      route.lock_version = Route.where(id: route.id).pick(:lock_version)
      route.compute
    }
  end
end
