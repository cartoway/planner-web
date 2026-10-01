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
    at = Time.current
    operation_ids = matching_operation_ids(hourly, planning_id, at)
    return if operation_ids.empty?

    operations = Operation.where(id: operation_ids).includes(:customer, operation_routes: :operation_stops)
    schema_version = Operations::ToHistoryStops.current_schema_version
    rows = operations.flat_map { |operation|
      Operations::ToHistoryStops.rows(operation, hourly: hourly, at: at, schema_version: schema_version)
    }
    return close_operations!(operation_ids, at) if rows.empty?

    replace_today_rows!(rows, planning_id, at)
    close_operations!(operation_ids, at)
  end

  def self.matching_operation_ids(hourly, planning_id, at)
    at_sql = ActiveRecord::Base.connection.quote(at.utc.strftime('%Y-%m-%d %H:%M:%S'))
    sql = <<~SQL
      SELECT operations.id
      FROM operations
      JOIN customers ON customers.id = operations.customer_id
      WHERE operations.status = 'in_progress'
        AND (#{planning_id || 'NULL'} IS NULL OR operations.planning_id = #{planning_id || 'NULL'})
        AND (#{hourly ? 'FALSE' : 'TRUE'} OR
          date_trunc('day', operations.date) + (date_trunc('day', operations.date) -
            date_trunc('day', operations.date) AT TIME ZONE (
              SELECT
                pg_timezone_names.name
              FROM
                users
                JOIN pg_timezone_names ON
                  pg_timezone_names.name LIKE '%/' || time_zone
              WHERE
                users.customer_id = customers.id
              ORDER BY
                users.id,
                pg_timezone_names.name
              LIMIT 1
            )
          ) +
          (customers.history_cron_hour || ' hours')::interval <= date_trunc('hour', #{at_sql}::timestamp)
        )
    SQL
    ActiveRecord::Base.connection.select_values(sql).map(&:to_i)
  end
  private_class_method :matching_operation_ids

  def self.replace_today_rows!(rows, planning_id, at)
    planning_ids = rows.map { |row| row[:planning_id] }.uniq
    route_ids = rows.map { |row| row[:route_id] }.uniq
    day_sql = ActiveRecord::Base.connection.quote(at.utc.to_date.to_s)

    scope = HistoryStop.where("date_trunc('day', date) = date_trunc('day', #{day_sql}::timestamp)")
    scope = scope.where(planning_id: planning_id) if planning_id
    scope = scope.where(planning_id: planning_ids, route_id: route_ids)
    scope.delete_all

    HistoryStop.insert_all(rows) if rows.any?
  end
  private_class_method :replace_today_rows!

  def self.close_operations!(operation_ids, at = Time.current)
    Operation.where(id: operation_ids, status: 'in_progress').update_all(
      status: 'historized',
      closed_at: at,
      updated_at: at
    )
  end
  private_class_method :close_operations!
end
