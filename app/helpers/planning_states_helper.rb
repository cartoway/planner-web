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

module PlanningStatesHelper
  PLANNING_STATE_EXCLUDED_BLOCKS = %w[speed quantities].freeze

  PLANNING_STATE_STAT_DIFF_METRICS = {
    'distance' => { stat_key: 'distance_total', format: :distance },
    'total_duration' => { stat_key: 'duration_total', format: :duration },
    'work_duration' => { stat_key: 'work_duration_total', format: :duration },
    'stops' => { stat_key: 'stops_size_active', format: :integer, higher_is_better: true },
    'visits_duration' => { stat_key: 'routes_visits_duration', format: :duration },
    'rests_duration' => { stat_key: 'routes_rests_duration', format: :duration },
    'drive_time' => { stat_key: 'routes_drive_time', format: :duration },
    'wait_time' => { stat_key: 'routes_wait_time', format: :duration },
    'vehicles' => { stat_key: 'vehicles_used', format: :integer },
    'emission' => { stat_key: 'routes_emission', format: :emission },
    'total_cost' => { stat_key: 'routes_cost', format: :currency },
    'total_revenue' => { stat_key: 'routes_revenue', format: :currency, higher_is_better: true },
    'balance' => { stat_key: :balance, format: :currency, higher_is_better: true }
  }.freeze

  def planning_state_statistics_locals(statistics, prefered_unit:, reference_statistics: nil)
    stats = (statistics || {}).stringify_keys
    stat_diffs =
      if reference_statistics.present?
        planning_state_stat_diffs(stats, reference_statistics, prefered_unit: prefered_unit)
      else
        {}
      end

    {
      prefered_unit: prefered_unit,
      distance: locale_distance(stats['distance_total'].to_f, prefered_unit),
      duration: time_over_day(stats['duration_total'].to_i),
      work_duration: time_over_day(stats['work_duration_total'].to_i),
      size: stats['stops_size'],
      size_active: stats['stops_size_active'],
      averages: planning_state_averages_from_statistics(stats, prefered_unit: prefered_unit),
      stat_diffs: stat_diffs
    }
  end

  def planning_state_statistics_html(statistics, prefered_unit:, reference_statistics: nil)
    locals = planning_state_statistics_locals(
      statistics,
      prefered_unit: prefered_unit,
      reference_statistics: reference_statistics
    )
    return '' if locals[:averages].blank? && locals[:size].blank?

    if respond_to?(:render_to_string)
      render_to_string(
        partial: 'planning_states/statistics_blocks',
        formats: [:html],
        locals: locals
      )
    else
      render(
        partial: 'planning_states/statistics_blocks',
        formats: [:html],
        locals: locals
      )
    end
  end

  def planning_state_header_block_order
    planning_header_block_order.reject { |key| PLANNING_STATE_EXCLUDED_BLOCKS.include?(key) }
  end

  def planning_state_stat_diffs(state_statistics, reference_statistics, prefered_unit:)
    state_stats = (state_statistics || {}).stringify_keys
    reference_stats = (reference_statistics || {}).stringify_keys

    PLANNING_STATE_STAT_DIFF_METRICS.each_with_object({}) do |(block_key, config), diffs|
      diff = planning_state_stat_diff(
        state_stats,
        reference_stats,
        config: config,
        prefered_unit: prefered_unit
      )
      diffs[block_key] = diff if diff
    end
  end

  private

  def planning_state_averages_from_statistics(stats, prefered_unit: nil)
    return nil if stats.blank?

    routes_cost = stats['routes_cost']
    routes_revenue = stats['routes_revenue']

    {
      routes_visits_duration: time_over_day(stats['routes_visits_duration'].to_i),
      routes_rests_duration: time_over_day(stats['routes_rests_duration'].to_i),
      routes_drive_time: time_over_day(stats['routes_drive_time'].to_i),
      routes_wait_time: time_over_day(stats['routes_wait_time'].to_i),
      vehicles_used: stats['vehicles_used'],
      vehicles: stats['vehicles'],
      emission: stats['routes_emission'] ? number_to_human(stats['routes_emission'], precision: 4) : '-',
      total_cost: routes_cost&.round(2),
      total_revenue: routes_revenue&.round(2),
      total_balance: ((routes_revenue || 0) - (routes_cost || 0)).round(2)
    }
  end

  def planning_state_stat_diff(state_stats, reference_stats, config:, prefered_unit:)
    state_value = planning_state_stat_value(state_stats, config[:stat_key])
    reference_value = planning_state_stat_value(reference_stats, config[:stat_key])
    return if state_value.nil? || reference_value.nil?

    diff = state_value - reference_value
    return if diff.zero?

    {
      formatted: format_planning_state_stat_diff(diff, config[:format], prefered_unit: prefered_unit),
      css_class: planning_state_stat_diff_css_class(diff, higher_is_better: config[:higher_is_better])
    }
  end

  def planning_state_stat_value(stats, stat_key)
    value =
      if stat_key == :balance
        planning_state_balance_value(stats)
      else
        stats[stat_key.to_s]
      end
    return if value.nil?

    value.to_f
  end

  def planning_state_balance_value(stats)
    stats.fetch('routes_revenue', 0).to_f - stats.fetch('routes_cost', 0).to_f
  end

  def planning_state_stat_diff_css_class(diff, higher_is_better: false)
    if higher_is_better
      diff.positive? ? 'text-success' : 'text-danger'
    else
      diff.negative? ? 'text-success' : 'text-danger'
    end
  end

  def format_planning_state_stat_diff(diff, format, prefered_unit:)
    abs = diff.abs
    formatted_abs =
      case format
      when :distance
        locale_distance(abs, prefered_unit)
      when :duration
        time_over_day(abs.to_i)
      when :currency
        abs.round(2).to_s
      when :integer
        abs.to_i.to_s
      when :emission
        number_to_human(abs, precision: 4)
      else
        abs.to_s
      end

    sign = diff.positive? ? '+' : '−'
    "#{sign}#{formatted_abs}"
  end
end
