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
  # - Spaces with :edit → create/update/destroy on catalog models
  # - operations space → sync / transmit / destroy / export
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
          # No block: CanCanCan does not run blocks for class-level can? checks.
          unless user.space_action_usable?(resource_key, 'edit')
            ability.cannot :create, model
            ability.cannot :new, model
            ability.cannot :update, model
            ability.cannot :destroy, model
          end

          # Read-only UI (GET edit) when space is visible but not usable; deny only when hidden.
          unless user.space_visible?(resource_key)
            ability.cannot :edit, model
          end
        end
      end

      unless user.space_action_usable?(VEHICLE_CONFIGURATION_SPACE, 'edit')
        ability.cannot :toggle, ::VehicleUsage
      end

      apply_vehicle_configuration_hidden_gate!(ability, user)
      apply_space_index_show_gate!(ability, user, 'tags', ::Tag)
      apply_space_index_show_gate!(ability, user, 'deliverable_units', DeliverableUnit)
      apply_space_index_show_gate!(ability, user, 'custom_attributes', CustomAttribute)
    end
    private_class_method :apply_edit_space_rules!

    def self.apply_operations_space_rules!(ability, user)
      unless user.space_visible?(OPERATIONS_SPACE)
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

    def self.apply_vehicle_configuration_hidden_gate!(ability, user)
      return if user.space_visible?(VEHICLE_CONFIGURATION_SPACE)

      ability.cannot :manage, VehicleUsageSet
      ability.cannot :manage, VehicleUsage
      ability.cannot :show, Vehicle
      if user.customer
        ability.cannot :delete_vehicle, ::Customer, id: user.customer.id
      end
    end
    private_class_method :apply_vehicle_configuration_hidden_gate!

    def self.apply_space_index_show_gate!(ability, user, space_key, model)
      return if user.space_visible?(space_key)

      ability.cannot :index, model
      ability.cannot :show, model
    end
    private_class_method :apply_space_index_show_gate!
  end
end
