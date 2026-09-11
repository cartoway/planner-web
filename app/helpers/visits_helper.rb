# Copyright © Mapotempo, 2016
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

require "#{Rails.root}/lib/visit_quantities"

module VisitsHelper
  def visit_quantities(visit, vehicle, options = {})
    VisitQuantities.normalize(visit, vehicle, options)
  end

  def visit_force_position_options_for_select
    [
      [t('activerecord.attributes.visits.force_position.neutral'), :neutral],
      [t('activerecord.attributes.visits.force_position.always_first'), :always_first],
      [t('activerecord.attributes.visits.force_position.always_final'), :always_final],
      [t('activerecord.attributes.visits.force_position.never_first'), :never_first]
    ]
  end

  def visit_force_position_options_for_select_selected(visit)
    [t("activerecord.attributes.visits.force_position.#{visit.force_position}"), visit.force_position]
  end

  def visit_planning_stops(visit)
    visit.stop_visits.includes(
      { photos_attachments: :blob },
      { route: [:planning, { vehicle_usage: :vehicle }] }
    ).sort_by { |stop|
      planning = stop.route.planning
      [planning.date&.to_time || Time.at(0), planning.id, stop.index || 0]
    }
  end

  def visit_stop_vehicle_name(stop)
    stop.route.vehicle_usage&.vehicle&.name || t('plannings.edit.out_of_route')
  end

  def visit_stop_vehicle_color(stop)
    stop.route.vehicle_usage&.vehicle&.color.presence || '#ffffff'
  end

  def visit_stop_status_label(stop)
    return if stop.status.blank?

    t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status)
  end

  def visit_stop_status_code(stop)
    stop.status&.downcase.presence
  end

  def visit_stop_visit_custom_attributes(visit)
    visit.destination.customer.custom_attributes.for_stop_visit.to_a
  end

  def visit_stop_filled_custom_attributes(stop, definitions)
    raw = stop.custom_attributes || {}
    definitions.select do |custom_attribute|
      key = CustomAttribute.storage_key_for(custom_attribute.name)
      next false unless raw.key?(key)

      custom_attribute.boolean? || raw[key].present?
    end
  end
end
