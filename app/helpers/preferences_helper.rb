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

  # Stops, delay, transmissions and quantities are rendered outside this order.
  def operation_preference_stat_keys
    planning_header_block_order.map(&:to_s) - %w[stops vehicles speed quantities transmitted]
  end

  def operation_plan_stat(key, plan, user)
    plan ||= {}
    unit = user.prefered_unit
    currency = I18n.t("all.unit.currency_symbol.#{user.prefered_currency}")
    case key
    when 'distance'
      { icon: 'fa-road', value: locale_distance(plan['distance'].to_f, unit) }
    when 'total_duration'
      { icon: 'fa-stopwatch', value: time_over_day(plan['duration'].to_i) }
    when 'work_duration'
      { icon: 'fa-user-clock', value: time_over_day(plan['work_duration'].to_i) }
    when 'drive_time'
      { icon: 'fa-road', value: time_over_day(plan['drive_time'].to_i) }
    when 'wait_time'
      { icon: 'fa-hourglass-half', value: time_over_day(plan['wait_time'].to_i) }
    when 'visits_duration'
      { icon: 'fa-business-time', value: time_over_day(plan['visits_duration'].to_i) }
    when 'rests_duration'
      { icon: 'fa-circle-pause', value: time_over_day(plan['rests_duration'].to_i) }
    when 'emission'
      { icon: 'fa-flask', value: "#{number_to_human(plan['emission'].to_f, precision: 4)} #{I18n.t('all.unit.kgco2e_html')}".html_safe }
    when 'total_cost'
      { icon: 'fa-coins', value: "#{plan['cost'].to_f.round(2)} #{currency}" }
    when 'total_revenue'
      { icon: 'fa-hand-holding-dollar', value: "#{plan['revenue'].to_f.round(2)} #{currency}" }
    when 'balance'
      balance = (plan['revenue'].to_f - plan['cost'].to_f).round(2)
      { icon: 'fa-scale-balanced', value: "#{balance} #{currency}" }
    end
  end

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

  # Destroy follows update mutability in form permissions.
  def current_user_form_destroy_enabled?(resource)
    current_user_form_update?(resource)
  end

  # Planning create/update forms (header flat form, new planning form, sidebar fragments).
  def current_user_planning_form_submit_enabled?(planning)
    planning.new_record? ? current_user_form_create?(:plannings) : current_user_form_update?(:plannings)
  end

  # Stores form (depot / reload); read-only GET edit when forms.stores visible but not usable.
  def current_user_store_form_submit_enabled?(store)
    store.new_record? ? current_user_form_create?(:stores) : current_user_form_update?(:stores)
  end

  # Destination + visits form; read-only edit when forms.destination is visible but not usable.
  def current_user_destination_form_submit_enabled?(destination)
    destination.new_record? ? current_user_form_create?(:destination) : current_user_form_update?(:destination)
  end

  def current_user_deliverable_unit_form_submit_enabled?(deliverable_unit)
    deliverable_unit.new_record? ? current_user_form_create?(:deliverable_units) : current_user_form_update?(:deliverable_units)
  end

  def current_user_custom_attribute_form_submit_enabled?(custom_attribute)
    custom_attribute.new_record? ? current_user_form_create?(:custom_attributes) : current_user_form_update?(:custom_attributes)
  end

  def current_user_customer_form_submit_enabled?(customer)
    return true if user_signed_in? && current_user.admin?

    customer.new_record? ? current_user_form_create?(:customer) : current_user_form_update?(:customer)
  end

  # Primary text for a stop row in the planning sidebar (field order from user preferences, max 3 fields).
  def stop_list_primary_line(stop)
    ids = stop_list_active_field_ids_for_ui
    parts = ids.filter_map { |fid| stop_list_field_part(stop, fid) }
    parts.compact_blank.join(' - ')
  end

  def stop_list_active_field_ids_for_ui
    if user_signed_in? && current_user.respond_to?(:stop_list_active_field_ids) && !current_user.admin?
      current_user.stop_list_active_field_ids
    else
      ::Preferences::Catalog::StopList::DEFAULT_ACTIVE.dup # unfrozen copy for callers that may mutate
    end
  end

  def stop_list_field_part(stop, field_id)
    val = ::Preferences::Catalog.stop_list_field_value(stop, field_id)
    return nil if val.blank?

    return "#{I18n.t('plannings.edit.popup.eta')} #{val}" if field_id.to_s == 'eta'

    val
  end
end
