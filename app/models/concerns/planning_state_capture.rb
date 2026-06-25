# frozen_string_literal: true

# Copyright © Cartoway, 2026
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

module PlanningStateCapture
  extend ActiveSupport::Concern

  included do
    has_many :planning_states, dependent: :destroy

    attr_accessor :skip_state_capture, :skip_vehicle_usage_set_callback
  end

  def capture_state!(trigger:)
    return if skip_state_capture
    return unless persisted?
    return if routes.empty?
    # Only recompute outdated routes; callers such as update_stop already compute the affected route.
    return unless compute_saved!(bang: false)

    snapshot_source = planning_for_state_snapshot

    planning_states.create!(
      captured_at: Time.current,
      trigger: trigger.to_s,
      category: PlanningState.category_for(trigger),
      payload: build_state_payload(snapshot_source),
      statistics: build_state_statistics(snapshot_source)
    )
    PlanningState.prune_excess!(id)
  end

  def route_data_statistics
    build_state_statistics
  end

  def reapply_state!(planning_state)
    payload = planning_state.payload
    return false if payload.blank?

    self.skip_state_capture = true
    self.skip_vehicle_usage_set_callback = true

    success = false
    Planning.transaction do
      self.vehicle_usage_set_id = payload['vehicle_usage_set_id']
      association(:vehicle_usage_set).reset
      vehicle_usage_set
      unless set_routes(build_routes_visits_from_payload(payload['routes']), false, true)
        raise ActiveRecord::Rollback
      end
      invalidate_planning_cache
      save!(touch: true)
      unless compute_saved!
        raise ActiveRecord::Rollback
      end
      success = true
    end
    success
  ensure
    self.skip_state_capture = false
    self.skip_vehicle_usage_set_callback = false
  end

  private

  def build_state_payload(planning = self)
    {
      'vehicle_usage_set_id' => planning.vehicle_usage_set_id,
      'routes' => planning.routes.map { |route| serialize_route_for_state(route) }
    }
  end

  def build_state_statistics(planning = self)
    averages_data = planning.averages('km') || {}
    distance_total = 0
    duration_total = 0
    work_duration_total = 0
    stops_size = 0
    stops_size_active = 0

    planning.routes.each do |route|
      distance_total += route.distance.to_f
      next unless route.vehicle_usage

      duration_total += route.total_duration.to_i
      work_duration_total += route.work_duration.to_i
      stops_size += route.stops_size.to_i
      stops_size_active += route.size_active.to_i
    end

    {
      'routes_cost' => averages_data[:routes_cost],
      'routes_revenue' => averages_data[:routes_revenue],
      'routes_drive_time' => averages_data[:routes_drive_time],
      'routes_wait_time' => averages_data[:routes_wait_time],
      'routes_visits_duration' => averages_data[:routes_visits_duration],
      'routes_rests_duration' => averages_data[:routes_rests_duration],
      'vehicles_used' => averages_data[:vehicles_used],
      'vehicles' => averages_data[:vehicles],
      'distance_total' => distance_total,
      'routes_emission' => averages_data[:routes_emission],
      'duration_total' => duration_total,
      'work_duration_total' => work_duration_total,
      'stops_size' => stops_size,
      'stops_size_active' => stops_size_active
    }.compact
  end

  def serialize_route_for_state(route)
    {
      'route_id' => route.id,
      'vehicle_usage_id' => route.vehicle_usage_id,
      'stops' => route.stops.sort_by(&:index).filter_map { |stop| serialize_stop_for_state(stop) }
    }
  end

  def serialize_stop_for_state(stop)
    case stop
    when StopVisit
      {
        'stop_id' => stop.id,
        'type' => 'visit',
        'visit_id' => stop.visit_id,
        'active' => stop.active,
        'index' => stop.index
      }
    when StopStore
      {
        'stop_id' => stop.id,
        'type' => 'store_reload',
        'store_reload_id' => stop.store_reload_id,
        'active' => stop.active,
        'index' => stop.index
      }
    end
  end

  def build_routes_visits_from_payload(routes_payload)
    visit_ids = []
    store_reload_ids = []
    routes_payload.each do |route_snapshot|
      route_snapshot['stops'].each do |stop_snapshot|
        case stop_snapshot['type']
        when 'visit'
          visit_ids << stop_snapshot['visit_id']
        when 'store_reload'
          store_reload_ids << stop_snapshot['store_reload_id']
        end
      end
    end

    visits_by_id = Visit.where(id: visit_ids.uniq).index_by(&:id)
    store_reloads_by_id = StoreReload.where(id: store_reload_ids.uniq).index_by(&:id)

    routes_payload.each_with_object({}) do |route_snapshot, hash|
      vehicle_usage_id = route_snapshot['vehicle_usage_id']
      next if vehicle_usage_id.nil?

      stops = route_snapshot.fetch('stops', []).sort_by { |stop| stop['index'].to_i }
      hash["route_#{vehicle_usage_id}"] = {
        vehicle_usage_id: vehicle_usage_id,
        visits: stops.filter_map { |stop_snapshot|
          build_visit_tuple_from_snapshot(stop_snapshot, visits_by_id, store_reloads_by_id)
        }
      }
    end
  end

  def build_visit_tuple_from_snapshot(stop_snapshot, visits_by_id, store_reloads_by_id)
    stop_attributes = {
      active: stop_snapshot['active'],
      stop_id: stop_snapshot['stop_id']
    }.compact

    case stop_snapshot['type']
    when 'visit'
      visit = visits_by_id[stop_snapshot['visit_id']]
      return unless visit

      [visit, stop_attributes]
    when 'store_reload'
      store_reload = store_reloads_by_id[stop_snapshot['store_reload_id']]
      return unless store_reload

      [store_reload, stop_attributes]
    end
  end

  def planning_for_state_snapshot
    Planning.where(id: id).preload_route_details.first!
  end

  def capture_state_for_mutation!(trigger)
    capture_state!(trigger: trigger)
  end
end
