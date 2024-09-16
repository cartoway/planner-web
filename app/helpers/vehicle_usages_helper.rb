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
module VehicleUsagesHelper
  def vehicle_usage_emission_consumption(vehicle_usage, unit)
    unit = !unit.nil? ? unit : 'km'
    capture do
      concat '%s&nbsp;%s'.html_safe % [vehicle_usage.vehicle.localized_emission, t('all.unit.kgco2e_l_html')] if vehicle_usage.vehicle.emission
      concat ' - ' if vehicle_usage.vehicle.emission && vehicle_usage.vehicle.consumption
      concat '%s&nbsp;%s'.html_safe % [vehicle_usage.vehicle.localized_consumption, unit == 'km' ? t('all.unit.l_100km') : t('all.unit.l_62Miles')] if vehicle_usage.vehicle.consumption
    end
  end

  def vehicle_usage_router(vehicle_usage)
    capture do
      if vehicle_usage.vehicle.router
        concat [vehicle_usage.vehicle.router.translated_name, t("activerecord.attributes.router.router_dimensions.#{vehicle_usage.vehicle.router_dimension || @customer.router_dimension}")].join(' - ')
      else
        concat span_tag([current_user.customer.router.translated_name, t("activerecord.attributes.router.router_dimensions.#{current_user.customer.router_dimension}")].join(' - '))
      end
    end
  end

  def vehicle_usage_store_name(vehicle_usage)
    capture do
      if vehicle_usage.default_store_start || vehicle_usage.default_store_stop
        if vehicle_usage.store_start
          concat '%s ' % [vehicle_usage.store_start.name]
        elsif vehicle_usage.vehicle_usage_set.store_start
          if vehicle_usage.store_stop
            concat '%s ' % [vehicle_usage.vehicle_usage_set.store_start.name]
          else
            concat span_tag('%s ' % [vehicle_usage.vehicle_usage_set.store_start.name])
          end
        else
          concat icon('fa-solid', 'ban', title: t('vehicle_usages.index.store.no_start'))
        end
        if vehicle_usage.default_store_start != vehicle_usage.default_store_stop
          concat icon('fa-solid', 'long-arrow-right')
          concat ' '
          if vehicle_usage.store_stop
            concat ' %s' % [vehicle_usage.store_stop.name]
          elsif vehicle_usage.vehicle_usage_set.store_stop
            concat '%s ' % [vehicle_usage.vehicle_usage_set.store_stop.name]
          else
            concat icon('fa-solid', 'ban', title: t('vehicle_usages.index.store.no_stop'))
          end
        elsif vehicle_usage.store_start
          concat icon('fa-solid', 'right-left', title: t('vehicle_usages.index.store.same_start_stop'))
        elsif vehicle_usage.vehicle_usage_set.store_start
          concat span_tag(icon('fa-solid', 'right-left', title: t('vehicle_usages.index.store.same_start_stop')))
        end
      end
    end
  end

  def vehicle_usage_store_hours(vehicle_usage)
    capture do
      if vehicle_usage.time_window_start
        concat vehicle_usage.time_window_start_time
        concat ('&nbsp;(+' + number_of_days(vehicle_usage.time_window_start).to_s + ')').html_safe if number_of_days(vehicle_usage.time_window_start)
        concat ' - '
      elsif vehicle_usage.vehicle_usage_set.time_window_start
        concat span_tag(vehicle_usage.vehicle_usage_set.time_window_start_time)
        concat span_tag(('&nbsp;(+' + number_of_days(vehicle_usage.vehicle_usage_set.time_window_start).to_s + ')').html_safe) if number_of_days(vehicle_usage.vehicle_usage_set.time_window_start)
        concat span_tag(' - ')
      end

      if vehicle_usage.time_window_end
        concat vehicle_usage.time_window_end_time
        concat ('&nbsp;(+' + number_of_days(vehicle_usage.time_window_end).to_s + ')').html_safe if number_of_days(vehicle_usage.time_window_end)
      elsif vehicle_usage.vehicle_usage_set.time_window_end
        concat span_tag(vehicle_usage.vehicle_usage_set.time_window_end_time)
        concat span_tag(('&nbsp;(+' + number_of_days(vehicle_usage.vehicle_usage_set.time_window_end).to_s + ')').html_safe) if number_of_days(vehicle_usage.vehicle_usage_set.time_window_end)
      end
    end
  end

  def vehicle_devices(vehicle)
    vehicle.devices.select{ |_key, value| value }.map{ |key, _value|
      # TODO: build name correctly, for Notico for instance
      s = key.to_s
      I18n.t('activerecord.attributes.vehicle.devices.' + s[0, s.rindex('_')] + '.title', default: s[0, s.rindex('_')])
    }.join(', ')
  end

  def vehicle_capacities(vehicle)
    capture do
      vehicle.customer.deliverable_units.each do |du|
        if vehicle.capacities && vehicle.capacities[du.id]
          concat Vehicle.localize_numeric_value(vehicle.capacities[du.id]) + (du.label ? "\u202F" + du.label : '')
        elsif vehicle.default_capacities && vehicle.default_capacities[du.id]
          concat span_tag(Vehicle.localize_numeric_value(vehicle.default_capacities[du.id]) + (du.label ? "\u202F" + du.label : ''))
        end
        concat ' '
      end
    end
  end

  def route_description(route)
    capture do
      concat [route.size_active, t('plannings.edit.stops')].join(' ')
      if route.start && route.end
        concat ' - %i:%02i - ' % [
          (route.end - route.start) / 60 / 60,
          (route.end - route.start) / 60 % 60
        ]
      end
      concat number_to_human(route.distance, units: :distance, precision: 3)
      if route.vehicle_usage.default_service_time_start
        concat ' - %s: %s' % [
          t('activerecord.attributes.vehicle_usage.service_time_start'),
          route.vehicle_usage.default_service_time_start_time
        ]
      end
      if route.vehicle_usage.default_service_time_end
        concat ' - %s: %s' % [
          t('activerecord.attributes.vehicle_usage.service_time_end'),
          route.vehicle_usage.default_service_time_end_time
        ]
      end
    end
  end

  def router_grouped_options(routers, vehicle_usage)
    grouped_options_for_select(
      [[t('activerecord.attributes.router.router_dimensions.time'), routers.select(&:time?).collect{ |router|
        [router.translated_name + ' - ' + t('activerecord.attributes.router.router_dimensions.time'), router.id.to_s + '_time']
      }]] + [[t('activerecord.attributes.router.router_dimensions.distance'), routers.select(&:distance?).collect{ |router|
        [router.translated_name + ' - ' + t('activerecord.attributes.router.router_dimensions.distance'), router.id.to_s + '_distance']
      }]],
      vehicle_usage.vehicle.router_id || vehicle_usage.vehicle.router_dimension ? (vehicle_usage.vehicle.router_id || vehicle_usage.vehicle.customer.router_id).to_s + '_' + (vehicle_usage.vehicle.router_dimension || vehicle_usage.vehicle.customer.router_dimension) : nil
    )
  end
end
