# Copyright © Mapotempo, 2018
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

module DeliverableByVehiclesHelper

  def plannings_by_ids(customer, planning_ids)
    customer.plannings.select { |p|
      planning_ids.include?(p.id.to_s)
    }
  end

  def routes_by_vehicle(plannings, vehicle_id)
    plannings.map { |pl|
      pl.routes.includes_stops.find { |r| (r.vehicle_usage? && r.vehicle_usage.vehicle_id == Integer(vehicle_id)) }
    }
  end

  def routes_quantities_by_deliverables(routes, deliverable_units)
    quantities = routes.collect { |r| r.nil? ? nil : r[:quantities] }
    deliverable_units.map.with_index { |du|
      quantities_map = map_quantities(quantities, du)
      average = quantities_map.reduce(0) { |sum, du_quantity|
        sum += du_quantity if !du_quantity.nil?
        sum
      }

      average = !quantities_map.empty? ? average / quantities_map.length : 0

      {
        label: du.label,
        icon: du.icon ? du.icon : 'fa-archive',
        average: average,
        quantities: quantities_map
      }
    }
  end

  def routes_total_infos(routes_quantities, routes)
    totals_per_route = routes.map.with_index { |r, i|
      if r.nil?
        {
          active: false
        }
      else
        quantity = routes_quantities.reduce(0) { |sum, du_quantity| sum + du_quantity[:quantities][i] }
        {
          active: true,
          total_quantity: number_with_precision(quantity, precision: 2, strip_insignificant_zeros: true),
          total_destinations: r.size_destinations,
          total_stops: r.size_active,
          total_drive_time: r.drive_time.to_i,
          total_visits_time: r.visits_duration.to_i,
          total_route_duration: r.visits_duration.to_i + r.wait_time.to_i + r.drive_time.to_i + (r.vehicle_usage ? r.vehicle_usage.service_time_start.to_i + r.vehicle_usage.service_time_end.to_i : 0)
        }
      end
    }

    averages = calc_averages(totals_per_route)

    {
      quantity_average: number_with_precision(!routes.empty? ? averages[:quantity_average] / routes.length : 0, precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true),
      destinations_average: number_with_precision(!routes.empty? ? averages[:destinations_average] / routes.length : 0, precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true),
      stops_average: number_with_precision(!routes.empty? ? averages[:stops_average] / routes.length : 0, precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true),
      visits_duration_average: !routes.empty? ? averages[:visits_time_average] / routes.length : 0,
      drive_time_average: !routes.empty? ? averages[:drive_time_average] / routes.length : 0,
      route_duration_average: !routes.empty? ? averages[:route_duration_average] / routes.length : 0,
      total_per_route: totals_per_route
    }
  end

  def calc_averages(totals_per_route)
    totals_per_route.reduce({
      destinations_average: 0,
      stops_average: 0,
      quantity_average: 0,
      drive_time_average: 0,
      visits_time_average: 0,
      route_duration_average: 0
    }) { |sum, r|
      if r[:active]
        sum[:destinations_average] += r[:total_destinations].to_f
        sum[:stops_average] += r[:total_stops].to_f
        sum[:quantity_average] += r[:total_quantity].to_f
        sum[:visits_time_average] += r[:total_visits_time]
        sum[:drive_time_average] += r[:total_drive_time]
        sum[:route_duration_average] += r[:total_route_duration]
      end
      sum
    }
  end

  def map_quantities(quantities, du)
    quantities.map { |q|
      if q.nil?
        q
      else
        q[du.id] ? q[du.id] : 0
      end
    }
  end
end
