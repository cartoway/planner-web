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
module Preferences
  # Maps Role.spaces permissions to CanCan denies.
  # - Space not usable (disabled or hidden) → no index/show/manage access
  # - Planning GET edit stays when space is visible (toolbar gates the workspace)
  # - Spaces with :edit usable → create/update/destroy on catalog models (not GET edit)
  # - operations space actions → sync / transmit / destroy / export
  # Toolbar planning/route/stop stays in PlanningToolbarAbilityMap.
  module SpaceAbilityMap
    OPERATIONS_SPACE = 'operations'
    VEHICLE_CONFIGURATION_SPACE = 'vehicle_usages'

    # spaces.destination applies to both Destination and Visit UIs.
    SPACE_KEY_MODELS = {
      'plannings' => [Planning],
      'destination' => [Destination, Visit],
      'vehicle_usages' => [VehicleUsage, VehicleUsageSet],
      'stores' => [Store],
      'tags' => [Tag],
      'customer' => [Customer],
      'deliverable_units' => [DeliverableUnit],
      'custom_attributes' => [CustomAttribute]
    }.freeze

    def self.apply_cannot_rules!(ability, user)
      return if user.blank? || user.admin?
      return unless user.respond_to?(:space_visible?)

      apply_edit_space_rules!(ability, user)
      apply_operations_space_rules!(ability, user)
    end

    def self.apply_edit_space_rules!(ability, user)
      SPACE_KEY_MODELS.each do |resource_key, models|
        models.each do |model|
          # Disabled or hidden space → no access (menu shows disabled when visible).
          unless user.space_usable?(resource_key)
            ability.cannot :index, model
            ability.cannot :show, model
            ability.cannot :create, model
            ability.cannot :new, model
            ability.cannot :update, model
            ability.cannot :destroy, model
            # Planning edit page stays open when the space is merely disabled (visible):
            # workspace tools are gated by planning_toolbar, not space :edit.
            if model != ::Planning || !user.space_visible?(resource_key)
              ability.cannot :edit, model
            end
            next
          end

          # No block: CanCanCan does not run blocks for class-level can? checks.
          # Do not cannot :edit here — GET edit stays available (alias edit→read); mutations only.
          unless user.space_action_usable?(resource_key, 'edit')
            ability.cannot :create, model
            ability.cannot :new, model
            ability.cannot :update, model
            ability.cannot :destroy, model
          end
        end
      end

      unless user.space_action_usable?(VEHICLE_CONFIGURATION_SPACE, 'edit')
        ability.cannot :toggle, ::VehicleUsage
      end

      unless user.space_action_usable?('destination', 'delete_all_destinations')
        ability.cannot :delete_all, ::Destination
      end

      unless user.space_action_usable?('destination', 'delete_all_visits')
        ability.cannot :delete_all, ::Visit
      end

      unless user.space_action_usable?('tags', 'delete_visits_by_tags')
        ability.cannot :delete_by_tags, ::Visit
      end

      unless user.space_action_usable?('tags', 'delete_destinations_by_tags')
        ability.cannot :delete_by_tags, ::Destination
      end

      apply_vehicle_configuration_access_gate!(ability, user)
    end
    private_class_method :apply_edit_space_rules!

    def self.apply_operations_space_rules!(ability, user)
      # Disabled or hidden → no access; menu keeps a disabled entry when visible.
      unless user.space_usable?(OPERATIONS_SPACE)
        ability.cannot :index, Operation
        ability.cannot :show, Operation
        ability.cannot :manage, Operation
        ability.cannot :manage, OperationRoute
        ability.cannot :manage, OperationStop
        return
      end

      unless user.space_action_usable?(OPERATIONS_SPACE, 'sync')
        ability.cannot :update, Operation
        ability.cannot :create, Operation
        ability.cannot :new, Operation
        ability.cannot :close, Operation
        ability.cannot :cancel, Operation
        ability.cannot :publish_operation, Planning
        ability.cannot :sync_operation, Planning
      end

      unless user.space_action_usable?(OPERATIONS_SPACE, 'transmit')
        ability.cannot :transmit, Operation
        ability.cannot :transmit_destinations, Operation
        ability.cannot :send_driver_sms, Operation
        ability.cannot :transmit, OperationRoute
      end

      unless user.space_action_usable?(OPERATIONS_SPACE, 'destroy')
        ability.cannot :destroy, Operation
      end

      unless user.space_action_usable?(OPERATIONS_SPACE, 'export')
        ability.cannot :export, Operation
      end
    end
    private_class_method :apply_operations_space_rules!

    def self.apply_vehicle_configuration_access_gate!(ability, user)
      return if user.space_usable?(VEHICLE_CONFIGURATION_SPACE)

      ability.cannot :manage, VehicleUsageSet
      ability.cannot :manage, VehicleUsage
      ability.cannot :show, Vehicle
      if user.customer
        ability.cannot :delete_vehicle, ::Customer, id: user.customer.id
      end
    end
    private_class_method :apply_vehicle_configuration_access_gate!
  end
end
