# Copyright © Mapotempo, 2017
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

require_relative '../sopac/cache'
require_relative '../sopac/broker_config'
require_relative '../sopac/broker_connection'
require_relative '../sopac/registry_bootstrap'

class Sopac < DeviceBase

  def definition
    {
      device: 'sopac',
      label: 'Sopac',
      label_small: 'Sopac',
      route_operations: [],
      has_sync: false,
      help: false,
      forms: {
        settings: {
          username: :text,
          password: :password,
          queue_prefix: :text
        },
        vehicle: {
          sopac_ids: :select
        },
      }
    }
  end

  def check_auth(credentials)
    config = SopacBroker::BrokerConfig.from_credentials(credentials)
    unless SopacBroker::BrokerConfig.valid?(config)
      raise DeviceServiceError, 'Sopac : broker configuration is incomplete'
    end

    SopacBroker::BrokerConnection.verify!(config)
  end

  def list_devices(customer)
    SopacBroker::RegistryBootstrap.call(customer) if SopacBroker::BrokerConfig.customer_enabled?(customer)

    cache = SopacBroker::Cache.new(customer.id)
    cache.devices_registry.map { |id, entry|
      {
        id: id,
        text: entry['label'] || entry[:label] || id
      }
    }
  end

  def vehicles_temperature(customer)
    cache = SopacBroker::Cache.new(customer.id)
    customer.vehicles.map { |v|
      ids = v.devices[:sopac_ids]
      next unless ids.is_a?(Array) && ids.any?

      {
        vehicle_id: v.id,
        vehicle_name: v.name,
        device_infos: ids.filter_map { |id|
          reading = measurement_reading(cache.read_measurement(id))
          next if reading.empty?

          {
            device_name: reading[:label],
            device_id: id,
            temperature: reading[:temperature],
            humidity: reading[:humidity],
            time: reading[:utc]
          }.compact
        }
      }
    }.compact
  end

  def vehicle_pos(customer)
    cache = SopacBroker::Cache.new(customer.id)
    customer.vehicles.filter_map { |v|
      ids = v.devices[:sopac_ids]
      next unless ids.is_a?(Array) && ids.any?

      position = resolve_vehicle_position(cache, ids)
      next unless position

      position.merge(vehicle_id: v.id, device_name: v.name)
    }
  end

  private

  def measurement_reading(cached)
    return {} unless cached

    measurements = cached['m'] || cached[:m]
    return {} unless measurements.is_a?(Array) && measurements.any?

    latest = measurements.max_by { |m| (m['utc'] || m[:utc]).to_i }
    utc_ms = (latest['utc'] || latest[:utc]).to_i
    time = utc_ms.positive? ? Time.at(utc_ms / 1000.0) : nil

    {
      label: cached['label'] || cached[:label],
      temperature: latest['t'] || latest[:t],
      humidity: latest['h'] || latest[:h],
      utc: time
    }.compact
  end

  def resolve_vehicle_position(cache, logger_ids)
    logger_ids.each do |logger_id|
      hub_id = cache.read_logger_hub(logger_id)
      next if hub_id.blank?

      if (gps = cache.read_hub_gps(hub_id))
        return position_from_gps(gps, hub_id)
      end

      if (hub = cache.read_hub(hub_id))
        return position_from_hub(hub, hub_id)
      end
    end
    nil
  end

  def position_from_gps(gps, hub_id)
    lat = gps['lat'] || gps[:lat]
    lon = gps['lon'] || gps[:lon]
    return nil if lat.nil? || lon.nil?

    device_time = gps['deviceTime'] || gps[:deviceTime]
    time = device_time.present? ? Time.at(device_time.to_i) : Time.current

    {
      lat: lat.to_f,
      lng: lon.to_f,
      speed: gps_speed_kmh(gps['speed'] || gps[:speed]),
      direction: gps_angle(gps['course'] || gps[:course]),
      time: time,
      device_name: hub_id
    }.compact
  end

  def position_from_hub(hub, hub_id)
    lat = hub['lat'] || hub[:lat]
    lon = hub['lon'] || hub[:lon]
    return nil if lat.nil? || lon.nil?

    last_seen = hub['lastSeen'] || hub[:lastSeen]
    time = last_seen.present? ? Time.parse(last_seen.to_s) : Time.current

    {
      lat: lat.to_f,
      lng: lon.to_f,
      time: time,
      device_name: hub_id
    }
  end

  def gps_speed_kmh(raw)
    return nil if raw.nil?

    raw.to_f / 10.0
  end

  def gps_angle(raw)
    return nil if raw.nil?

    raw.to_f / 100.0
  end
end
