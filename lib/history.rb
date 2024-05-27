# Copyright © Cartoway, 2024
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

class History
  def self.historize(hourly, planning_id)
    ActiveRecord::Base.connection.execute("
DELETE FROM history_stops
WHERE
  date_trunc('day', date) = date_trunc('day', now()) AND
  (planning_id IS NULL OR planning_id = #{planning_id || 'NULL'})
;
INSERT INTO history_stops
SELECT
  (SELECT max(version) FROM schema_migrations) AS schema_version,
  #{hourly ? 'date_trunc(\'hour\', now())' : 'now()'} AS date,
  customers.reseller_id AS reseller_id,
  customers.id AS customer_id,
  vehicle_usages.id AS vehicle_usage_id,
  vehicles.id AS vehicle_id,
  routers.mode AS router_mode,
  plannings.id AS planning_id,
  routes.id AS route_id,
  jsonb_strip_nulls(row_to_json(vehicle_usages)::jsonb) - 'created_at' - 'updated_at' - 'id' - 'vehicle_usage_id' AS vehicle_usage,
  jsonb_strip_nulls(row_to_json(vehicles)::jsonb) - 'created_at' - 'updated_at' - 'id' AS vehicle,
  jsonb_strip_nulls(row_to_json(plannings)::jsonb) - 'created_at' - 'updated_at' - 'id' - 'customer_id' AS planning,
  jsonb_strip_nulls(row_to_json(routes)::jsonb) - 'created_at' - 'updated_at' - 'id' - 'geojson_tracks' - 'geojson_points' - 'planning_id' - 'vehicle_usage_id' AS route,
  CASE WHEN count(stops) > 0 THEN
      jsonb_agg(jsonb_build_object(
          'stop', jsonb_strip_nulls(row_to_json(stops)::jsonb) - 'created_at' - 'updated_at' - 'id' - 'visit_id' - 'route_id',
          'visit', jsonb_strip_nulls(row_to_json(visits)::jsonb) - 'created_at' - 'updated_at' - 'id' - 'destination_id',
          'destination', jsonb_strip_nulls(row_to_json(destinations)::jsonb) - 'created_at' - 'updated_at' - 'id'
      ) ORDER BY stops.index)
  END AS stops,
  count(stops) AS stops_count,
  sum(CASE WHEN vehicles.id IS NOT NULL AND stops.active THEN 1 ELSE 0 END) AS stops_active_count
FROM
  customers
  JOIN plannings ON
      plannings.customer_id = customers.id
  JOIN routes ON
      routes.planning_id = plannings.id
  LEFT JOIN stops ON
      stops.route_id = routes.id
  LEFT JOIN visits ON
      visits.id = stops.visit_id
  LEFT JOIN destinations ON
      destinations.id = visits.destination_id
  LEFT JOIN vehicle_usages ON
      vehicle_usages.id = routes.vehicle_usage_id
  LEFT JOIN vehicles ON
      vehicles.id = vehicle_usages.vehicle_id
  LEFT JOIN routers ON
      routers.id = coalesce(vehicles.router_id, customers.router_id)
WHERE
  (#{planning_id || 'NULL'} IS NULL OR plannings.id = #{planning_id || 'NULL'}) AND
  (#{hourly ? 'FALSE' : 'TRUE'} OR
    date_trunc('day', plannings.date) + (date_trunc('day', plannings.date) -
      date_trunc('day', plannings.date) AT TIME ZONE (
        SELECT
          pg_timezone_names.name
        FROM
          users
          JOIN pg_timezone_names ON
            pg_timezone_names.name LIKE '%/' || time_zone
        WHERE
          users.customer_id = customer_id
        ORDER BY
          users.id,
          pg_timezone_names.name
        LIMIT 1
      )
    ) +
    (customers.history_cron_hour || ' hours')::interval = date_trunc('hour', now())
  )
GROUP BY
  customers.id,
  plannings.id,
  routes.id,
  vehicle_usages.id,
  vehicles.id,
  routers.id
    ")
  end
end
