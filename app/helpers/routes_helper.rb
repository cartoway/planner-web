# Copyright © Mapotempo, 2013-2016
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
require 'barby/barcode/code_128'

module RoutesHelper
  def display_start_time(route)
    route.start + route.service_time_start_value if route.start && route.service_time_start_value
  end

  def display_end_time(route)
    route.end - route.service_time_end_value if route.end && route.service_time_end_value
  end

  def route_quantities(planning, route)
    deliverable_unit_hash = planning.customer.deliverable_units.index_by(&:id)
    vehicle = route.vehicle_usage.try(:vehicle)
    route.quantities.collect{ |id, v|
      unit = deliverable_unit_hash[id]
      next unless unit

      loading = vehicle && route.loadings[id]
      capacity = vehicle && vehicle.default_capacities[id]
      next if v.zero? && !loading

      q =
        if loading && loading > 0
          number_with_precision(loading, precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true)
        else
          number_with_precision(v, precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s
        end
      q += ' / ' + number_with_precision(vehicle.default_capacities[id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s if vehicle && vehicle.default_capacities[id]
      q += "\u202F" + unit.label if unit.label
      {
        id: id,
        quantity: v,
        loading: loading,
        label: unit.label,
        unit_icon: unit.default_icon,
        quantity_formatted: q,
        out_of_capacity: capacity && v > capacity
      }
    }.compact
  end

  def export_column_titles(customer, columns, custom_columns)
    retrieve_matching_columns(customer, columns).map{ |c|
      if custom_columns&.key?(c)
        custom_columns[c]
      elsif (m = /^(.+)\[(.*)\]$/.match(c))
        I18n.t("plannings.export_file.#{m[1]}") + "[#{m[2]}]"
      elsif (m = /^([a-z]+(?:_[a-z]+)*)(\d+)$/.match(c))
        deliverable_unit = customer.deliverable_units.where(id: m[2].to_i).first
        I18n.t('destinations.import_file.' + m[1]) + (deliverable_unit.label ? "[#{deliverable_unit.label}]" : "#{deliverable_unit.id}")
      else
        I18n.t('plannings.export_file.' + c.to_s)
      end
    }
  end

  def retrieve_matching_columns(customer, columns)
    columns.map{ |column|
      if (m = /^(.+)\[(.*)\]$/.match(column))
        deliverable_unit = customer.deliverable_units.where(label: m[2])&.first

        if deliverable_unit
          "#{m[1]}#{deliverable_unit&.id || m[2]}"
        else
          column
        end
      else
        column
      end
    }
  end

  # Devices hashes from PlanningHelper, collect all devices binded with the current route.
  # Otherwise, takes the Device's id from the vehicle model
  def route_devices(devices, route)
    route_devices_hash = {}
    devices_route = route.vehicle_usage.vehicle.devices

    devices_route.each do |key, value|
      if devices && devices.key?(key)
        match_device = if value.is_a?(Array)
          { items: devices[key].select{ |dv| value.include? dv[:id] } }
        else
          devices[key].find{ |dv| dv[:id] == value }
        end
        route_devices_hash[key] = match_device unless match_device.nil? || match_device.empty?
      else
        route_devices_hash[key] = value
      end
    end
    route_devices_hash
  end

  def barcode(code, refs)
    refs.split(',').collect(&:strip).collect{ |ref|
      begin
        "<div class=\"ref barcode barcode_#{code}\">" +
          Barby::Code128B.new(ref).encoding.split('').collect{ |c|
            "<span class=\"barcode_x barcode_#{c}\"></span>"
          }.join('') +
          '</div>'
      rescue StandardError
        "<span class=\"ui-state-error\">#{I18n.t('errors.routes.bad_barcode_char')}</span>"
      end
    }.join("\n").html_safe
  end

  def driver_url(planning, route_hash)
    reseller = planning.customer.reseller
    url = "#{reseller.url_protocol}://#{reseller.host}/routes/#{route_hash[:route_id]}/mobile?driver_token=#{route_hash[:driver_token]}"

    Rails.application.config.url_shortener.shorten(url)
  end
end
