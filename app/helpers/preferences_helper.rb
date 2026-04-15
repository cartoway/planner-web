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
module PreferencesHelper
  extend ActiveSupport::Concern

  def planning_header_block_order
    if user_signed_in? && current_user.respond_to?(:header_block_order)
      current_user.header_block_order(:planning)
    else
      Preferences::Catalog.header_zone_active_default('planning')
    end
  end

  def route_header_block_order
    if user_signed_in? && current_user.respond_to?(:header_block_order)
      current_user.header_block_order(:route)
    else
      Preferences::Catalog.header_zone_active_default('route')
    end
  end

  # Fixed route-head toolbar groups
  ROUTE_TOOLBAR_VEHICLE_OPTIMIZE = %w[vehicle_usage optimize].freeze
  ROUTE_TOOLBAR_STOPS = %w[stops].freeze
  ROUTE_TOOLBAR_VIEW_EXPORT = %w[view lock export].freeze

  def toolbar_operation_visible?(zone, operation_id)
    return true unless user_signed_in? && current_user.respond_to?(:operation_segment_visible?)

    current_user.operation_segment_visible?(zone, operation_id)
  end

  def toolbar_operation_usable?(zone, operation_id)
    return true unless user_signed_in? && current_user.respond_to?(:operation_segment_usable?)

    current_user.operation_segment_usable?(zone, operation_id)
  end

  def toolbar_operation_disabled?(zone, operation_id)
    toolbar_operation_visible?(zone, operation_id) && !toolbar_operation_usable?(zone, operation_id)
  end

  # Form policy (vehicle_usage toolbar vs forms.vehicle_usages.visible).
  def current_user_form_visible?(resource)
    return true unless user_signed_in? && current_user.respond_to?(:form_visible?)

    current_user.form_visible?(resource)
  end

  def current_user_form_create?(resource)
    return true unless user_signed_in? && current_user.respond_to?(:form_create?)

    current_user.form_create?(resource)
  end

  def current_user_form_update?(resource)
    return true unless user_signed_in? && current_user.respond_to?(:form_update?)

    current_user.form_update?(resource)
  end

  # Planning create/update forms (header flat form, new planning form, sidebar fragments).
  def current_user_planning_form_submit_enabled?(planning)
    planning.new_record? ? current_user_form_create?(:plannings) : current_user_form_update?(:plannings)
  end

  # Stores form (depot / reload); read-only GET edit when forms.stores visible but not usable.
  def current_user_store_form_submit_enabled?(store)
    store.new_record? ? current_user_form_create?(:stores) : current_user_form_update?(:stores)
  end
end
