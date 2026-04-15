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
  # Maps Preferences::Catalog form resources (forms.*) to CanCan :create / :update on models.
  # Denies when the user cannot create/update that form in the UI (role or catalog form permissions).
  module FormAbilityMap
    # Admin DnD label (fr): "Configurations de véhicules" — hidden tier must lock fleet UIs (sets, usages, vehicles).
    VEHICLE_CONFIGURATION_FORMS_KEY = 'vehicle_usages'

    RESOURCE_MODEL = ::Preferences::Catalog::FORM_RESOURCES.index_with do |key|
      case key
      when 'plannings' then Planning
      when 'destinations' then Destination
      when 'visits' then Visit
      when 'vehicle_usages' then VehicleUsage
      when 'stores' then Store
      else
        raise ArgumentError, "FormAbilityMap: add model for forms.#{key}"
      end
    end.freeze

    def self.apply_cannot_rules!(ability, user)
      return if user.blank? || user.admin?

      RESOURCE_MODEL.each do |resource_key, model|
        # No block: CanCanCan does not run blocks for class-level can? checks (e.g. can?(:create, Destination)),
        # so conditional denies must be registered as plain cannot rules when the form disallows the action.
        if user.respond_to?(:form_create?) && !user.form_create?(resource_key)
          ability.cannot :create, model
          ability.cannot :new, model
        end

        # Mutable actions: only when visible and usable (form_policy create/update).
        if user.respond_to?(:form_update?) && !user.form_update?(resource_key)
          ability.cannot :update, model
        end

        # Read-only UI (e.g. planning map GET edit): allowed when the form resource is visible but not usable;
        # deny opening edit screens only when the resource is hidden in permissions DnD.
        if user.respond_to?(:form_visible?) && !user.form_visible?(resource_key)
          ability.cannot :edit, model
        end
      end

      # VehicleUsagesController#toggle mutates the record like #update.
      if user.respond_to?(:form_update?) && !user.form_update?(VEHICLE_CONFIGURATION_FORMS_KEY)
        ability.cannot :toggle, ::VehicleUsage
      end

      apply_vehicle_configuration_hidden_gate!(ability, user)
    end

    # When forms.vehicle_usages is in the hidden tier (not visible), block all fleet configuration screens.
    def self.apply_vehicle_configuration_hidden_gate!(ability, user)
      return if user.blank? || user.admin?
      return unless user.respond_to?(:form_visible?)
      return if user.form_visible?(VEHICLE_CONFIGURATION_FORMS_KEY)

      ability.cannot :manage, VehicleUsageSet
      ability.cannot :manage, VehicleUsage
      ability.cannot :show, Vehicle
      # Member action on CustomersController (vehicle list tab / API); scoped to own customer.
      if user.customer
        ability.cannot :delete_vehicle, ::Customer, id: user.customer.id
      end
    end
    private_class_method :apply_vehicle_configuration_hidden_gate!
  end
end
