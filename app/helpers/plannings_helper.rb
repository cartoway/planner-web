# Copyright © Mapotempo, 2013-2014
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
module PlanningsHelper
  def planning_vehicles_array(planning)
    customer = planning.customer
    planning.vehicle_usage_set.vehicle_usages.active.map{ |vehicle_usage|
      {
        id: vehicle_usage.vehicle.id,
        text: vehicle_usage.vehicle.name,
        color: vehicle_usage.vehicle.color,
        available_position: customer.device.available_position?(vehicle_usage.vehicle) && vehicle_usage.active?,
        cache_position: customer.device.available_cache_position?(vehicle_usage.vehicle) && vehicle_usage.active?
      }
    }
  end

  def planning_vehicles_usages_map(planning)
    PlanningConcern.vehicles_usages_map(planning)
    planning.vehicle_usage_set.vehicle_usages.active.each_with_object({}) do |vehicle_usage, hash|
      router_name =
        vehicle_usage.vehicle.default_router.name_locale[I18n.locale.to_s] ||
        vehicle_usage.vehicle.default_router.name_locale[I18n.default_locale.to_s] ||
        vehicle_usage.vehicle.default_router.name
      hash[vehicle_usage.vehicle_id] =
        vehicle_usage
        .vehicle.slice(:name, :color, :capacities, :default_capacities)
        .merge(
          vehicle_usage_id: vehicle_usage.id,
          vehicle_id: vehicle_usage.vehicle_id,
          router_dimension: vehicle_usage.vehicle.default_router_dimension,
          work_or_window_time: vehicle_usage.work_or_window_time,
          vehicle_quantities: PlanningsHelper.vehicle_usage_quantities(planning, vehicle_usage),
          router_name: router_name
        )
    end
  end

  def planning_summary(planning)
    {
      planning_id: planning.id,
      planning_ref: planning.ref,
      external_callback_name: planning.customer.enable_external_callback && planning.customer.external_callback_name,
      external_callback_url: planning.customer.enable_external_callback && planning.customer.external_callback_url,
      routes: planning.routes.map{ |route|
        {
          route_id: route.id,
          vehicle_usage_id: route.vehicle_usage_id,
          vehicle_id: route.vehicle_usage&.vehicle_id,
          name: (route.ref || '') + (route.vehicle_usage&.vehicle&.name || ''),
          color: route.color || route.vehicle_usage&.vehicle&.color,
          hidden: route.hidden,
          locked: route.locked
        }.delete_if{ |_k, v| v.nil? }
      }
    }
  end

  def self.vehicle_usage_quantities(planning, vehicle_usage)
    quantities = []
    planning.routes.find{ |route|
      route.vehicle_usage == vehicle_usage
    }.quantities.select{ |_k, value| value > 0 }.each do |id, value|
      unit = planning.customer.deliverable_units.find{ |du| du.id == id }
      next unless unit

      quantities << {
        deliverable_unit_id: unit.id,
        label: unit.label,
        unit_icon: unit.default_icon,
        quantity: value
      }
    end
    quantities
  end

  def planning_quantities(planning)
    planning.quantities
  end

  # It collect the enabled devices, instantiate the service then list them
  def planning_devices(customer)
    devices = {}
    device_confs = customer.device.configured_definitions || []

    device_confs.each { |_key, definition|
      service_class = "#{definition[:device].camelize}Service".constantize
      device = service_class.new(customer: customer)

      next unless device.respond_to?(:list_devices)

      begin
        list = device.list_devices
        devices[device.service_name_id] = list unless list.empty?
      rescue StandardError => e
        Rails.logger.info(e)
        raise e if ENV['RAILS_ENV'] == 'test'
      end
    }
    devices
  end

  def available_temperature?
    device_list = current_user.customer.vehicles.reject { |e|
      e.devices[:sopac_ids].nil?
    }
    !device_list.empty?
  end

  def optimization_duration(customer)
    {
      min: customer.optimization_minimal_time || Mapotempo::Application.config.optimize_minimal_time,
      max: customer.optimization_time || Mapotempo::Application.config.optimize_time
    }
  end

  def external_callback_converted_url(planning_summary, current_user, route_hash = nil)
    if planning_summary[:external_callback_url]
      external_url =
        planning_summary[:external_callback_url].gsub(/\{customer_id\}/i, current_user.customer_id.to_s)
                                                .gsub(/\{planning_id\}/i, planning_summary[:planning_id].to_s)
                                                .gsub(/\{planning_ref\}/i, planning_summary[:planning_ref] || 'null')
                                                .gsub(/\{api_key\}/i, current_user.api_key)
      if route_hash
        external_url =
          external_url.gsub(/\{route_id\}/i, route_hash[:route_id].to_s)
                      .gsub(/\{route_ref\}/i, route_hash[:ref] || 'null')
      end
      external_url
    else
      ''
    end
  end
end
