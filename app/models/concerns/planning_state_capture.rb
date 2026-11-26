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
  using AfterCommitHelper

  included do
    has_many :planning_states, dependent: :destroy

    attr_accessor :skip_state_capture, :skip_vehicle_usage_set_callback, :skip_compute_on_vehicle_usage_set_change
  end

  def capture_state!(trigger:)
    return if skip_state_capture
    return unless persisted?

    attrs = build_capture_attributes(trigger)
    return unless attrs

    persist_captured_state!(attrs)
  end

  # Build snapshot now (correct undo point), persist insert after commit via delayed job.
  def capture_state_later!(trigger:)
    return if skip_state_capture
    return unless persisted?

    attrs = build_capture_attributes(trigger)
    return unless attrs

    return persist_captured_state!(attrs) unless Planner::Application.config.delayed_job_use

    job = PlanningStateCaptureJob.new(
      attrs[:planning_id],
      attrs[:captured_at],
      attrs[:trigger],
      attrs[:category],
      PlanningStateCaptureJob.compress_payload(attrs[:payload]),
      attrs[:statistics]
    )
    after_commit { Delayed::Job.enqueue(job) }
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
      unless apply_routes_from_state_payload(payload['routes'], recompute: false, ignore_errors: true)
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

  def build_capture_attributes(trigger)
    snapshot_source = planning_for_state_snapshot
    return if trigger.to_s != 'import' && snapshot_source.routes.empty?

    {
      planning_id: id,
      captured_at: Time.current,
      trigger: trigger.to_s,
      category: PlanningState.category_for(trigger),
      payload: build_state_payload(snapshot_source),
      statistics: build_state_statistics(snapshot_source)
    }
  end

  def persist_captured_state!(attrs)
    # Use the association so in-memory planning_states stays consistent for callers/tests.
    planning_states.create!(attrs.except(:planning_id))
    PlanningState.prune_excess!(id)
  end

  def build_state_payload(planning = self)
    stops_by_route_id = serialized_stops_by_route_id(planning.routes.map(&:id))
    {
      'vehicle_usage_set_id' => planning.vehicle_usage_set_id,
      'routes' => planning.routes.map { |route|
        {
          'route_id' => route.id,
          'ref' => route.ref,
          'vehicle_usage_id' => route.vehicle_usage_id,
          'stops' => stops_by_route_id[route.id] || []
        }
      }
    }
  end

  def build_state_statistics(planning = self)
    averages_data = planning.averages('km') || {}
    distance_total = 0
    duration_total = 0
    work_duration_total = 0
    stops_size = 0
    stops_size_active = 0
    vehicles = 0
    vehicles_used = 0

    planning.routes.each do |route|
      distance_total += route.distance.to_f
      stops_size += route.stops_size.to_i
      next unless route.vehicle_usage

      vehicles += 1
      vehicles_used += 1 if route.size_active_destinations.positive?
      duration_total += route.total_duration.to_i
      work_duration_total += route.work_duration.to_i
      stops_size_active += route.size_active.to_i
    end

    {
      'routes_cost' => averages_data[:routes_cost],
      'routes_revenue' => averages_data[:routes_revenue],
      # Duration keys stay present when averages is nil (no active tour / stale dest counters).
      'routes_drive_time' => averages_data.fetch(:routes_drive_time, 0),
      'routes_wait_time' => averages_data.fetch(:routes_wait_time, 0),
      'routes_visits_duration' => averages_data.fetch(:routes_visits_duration, 0),
      'routes_rests_duration' => averages_data.fetch(:routes_rests_duration, 0),
      # Always keep vehicle counts (averages may be nil when no active tour)
      'vehicles_used' => averages_data.fetch(:vehicles_used, vehicles_used),
      'vehicles' => averages_data.fetch(:vehicles, vehicles),
      'distance_total' => distance_total,
      'routes_emission' => averages_data[:routes_emission],
      'duration_total' => duration_total,
      'work_duration_total' => work_duration_total,
      'stops_size' => stops_size,
      'stops_size_active' => stops_size_active
    }.compact
  end

  # select_rows + one-pass serialize: avoids AR pluck casting and an intermediate row array.
  def serialized_stops_by_route_id(route_ids)
    return {} if route_ids.empty?

    sql = Stop.where(route_id: route_ids)
              .order(:route_id, :index)
              .select(:route_id, :type, :visit_id, :store_reload_id, :active, :index)
              .to_sql
    ActiveRecord::Base.connection.select_rows(sql).each_with_object({}) do |row, hash|
      route_id, type, visit_id, store_reload_id, active, index = row
      active_flag = [true, 't'].include?(active)
      stop = case type
             when 'StopVisit'
               {
                 'type' => 'visit',
                 'visit_id' => visit_id.to_i,
                 'active' => active_flag,
                 'index' => index.to_i
               }
             when 'StopStore'
               {
                 'type' => 'store_reload',
                 'store_reload_id' => store_reload_id.to_i,
                 'active' => active_flag,
                 'index' => index.to_i
               }
             when 'StopRest'
               {
                 'type' => 'rest',
                 'active' => active_flag,
                 'index' => index.to_i
               }
             end
      next unless stop

      (hash[route_id.to_i] ||= []) << stop
    end
  end

  def apply_routes_from_state_payload(routes_payload, recompute: true, ignore_errors: false)
    routes_visits = build_routes_visits_from_payload(routes_payload)
    out_of_route_objects =
      build_out_of_route_objects_from_payload(routes_payload) +
      build_missing_visits_out_of_route_objects(routes_payload)

    default_empty_routes(ignore_errors)
    return if routes_visits.size > routes.size - 1

    index_routes = (1..routes.size).to_a
    routes_visits.each_value{ |routes_visit|
      index = route_index_for_routes_visit(routes_visit)
      index_routes.delete(index) if index
    }

    ref_updates = []
    routes_visits.each_value{ |routes_visit|
      route_index = route_index_for_routes_visit(routes_visit) || index_routes.shift
      routes[route_index].ref = routes_visit[:ref]
      ref_updates << { id: routes[route_index].id, ref: routes_visit[:ref] }
      routes[route_index].stops.delete_all
      routes[route_index].add_objects(routes_visit[:visits], recompute, ignore_errors)
    }
    ref_updates << { id: routes.find { |route| !route.vehicle_usage? }.id, ref: nil }

    if ref_updates.any?
      fragments = ref_updates.map { 'WHEN ? THEN ?' }.join(' ')
      binds = ref_updates.flat_map { |update| [update[:id], update[:ref]] }
      Route.where(id: ref_updates.map { |update| update[:id] })
           .update_all(["ref = CASE id #{fragments} END, outdated = true", *binds])
    end

    routes.find { |route| !route.vehicle_usage? }.set_objects(out_of_route_objects, recompute, ignore_errors)
    self
  end

  def build_out_of_route_objects_from_payload(routes_payload)
    route_snapshot = routes_payload.find { |route| route['vehicle_usage_id'].nil? }
    return [] unless route_snapshot

    visit_ids = []
    store_reload_ids = []
    route_snapshot.fetch('stops', []).each do |stop_snapshot|
      case stop_snapshot['type']
      when 'visit'
        visit_ids << stop_snapshot['visit_id']
      when 'store_reload'
        store_reload_ids << stop_snapshot['store_reload_id']
      end
    end

    visits_by_id = Visit.where(id: visit_ids.uniq).index_by(&:id)
    store_reloads_by_id = StoreReload.where(id: store_reload_ids.uniq).index_by(&:id)

    route_snapshot.fetch('stops', []).sort_by { |stop| stop['index'].to_i }.filter_map do |stop_snapshot|
      build_visit_tuple_from_snapshot(stop_snapshot, visits_by_id, store_reloads_by_id)
    end
  end

  def build_missing_visits_out_of_route_objects(routes_payload)
    snapshot_visit_ids =
      routes_payload.flat_map { |route_snapshot|
        route_snapshot.fetch('stops', []).filter_map { |stop_snapshot|
          stop_snapshot['visit_id'] if stop_snapshot['type'] == 'visit'
        }
      }.uniq

    routes.flat_map(&:stops)
          .grep(StopVisit)
          .reject { |stop| snapshot_visit_ids.include?(stop.visit_id) }
          .sort_by { |stop| [stop.route.vehicle_usage? ? 0 : 1, stop.route_id.to_i, stop.index.to_i] }
          .map { |stop| [stop.visit, { active: false }] }
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
        ref: route_snapshot['ref'],
        vehicle_usage_id: vehicle_usage_id,
        visits: stops.filter_map { |stop_snapshot|
          build_visit_tuple_from_snapshot(stop_snapshot, visits_by_id, store_reloads_by_id)
        }
      }
    end
  end

  def build_visit_tuple_from_snapshot(stop_snapshot, visits_by_id, store_reloads_by_id)
    stop_attributes = {
      active: stop_snapshot['active']
    }
    stop_attributes.compact!

    case stop_snapshot['type']
    when 'visit'
      visit = visits_by_id[stop_snapshot['visit_id']]
      return unless visit

      [visit, stop_attributes]
    when 'store_reload'
      store_reload = store_reloads_by_id[stop_snapshot['store_reload_id']]
      return unless store_reload

      [store_reload, stop_attributes]
    when 'rest'
      [:rest, stop_attributes]
    end
  end

  def planning_for_state_snapshot
    # route_data + vehicle_usage(+set for service times in total/work_duration);
    # stops come from pluck in build_state_payload.
    Planning.where(id: id).preload(
      routes: Planning::ROUTE_DATA_PRELOAD + [{ vehicle_usage: :vehicle_usage_set }]
    ).first!
  end

  def capture_state_for_mutation!(trigger)
    capture_state!(trigger: trigger)
  end
end
