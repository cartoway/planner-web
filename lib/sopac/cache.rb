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

module SopacBroker
  class Cache
    REGISTRY_KEY = 'devices_registry'

    def initialize(customer_id, store: nil)
      @customer_id = customer_id
      @store = store || Planner::Application.config.devices.sopac_cache_object
    end

    def write_measurement(logger_id, data)
      @store.write(measurement_key(logger_id), data)
      register_device(logger_id, data)
      hub_id = latest_measurement_hub(data)
      write_logger_hub(logger_id, hub_id) if hub_id.present?
    end

    def read_measurement(logger_id)
      @store.read(measurement_key(logger_id))
    end

    def write_hub(hub_id, data)
      @store.write(hub_key(hub_id), data)
    end

    def read_hub(hub_id)
      @store.read(hub_key(hub_id))
    end

    def write_hub_gps(hub_id, data)
      @store.write(hub_gps_key(hub_id), data)
    end

    def read_hub_gps(hub_id)
      @store.read(hub_gps_key(hub_id))
    end

    def read_logger_hub(logger_id)
      @store.read(logger_hub_key(logger_id))
    end

    def devices_registry
      @store.read(registry_key) || {}
    end

    private

    def base_key
      "sopac:customer:#{@customer_id}"
    end

    def measurement_key(logger_id)
      "#{base_key}:measurement:#{logger_id}"
    end

    def hub_key(hub_id)
      "#{base_key}:hub:#{hub_id}"
    end

    def hub_gps_key(hub_id)
      "#{base_key}:hub_gps:#{hub_id}"
    end

    def logger_hub_key(logger_id)
      "#{base_key}:logger_hub:#{logger_id}"
    end

    def registry_key
      "#{base_key}:#{REGISTRY_KEY}"
    end

    def register_device(logger_id, data)
      registry = devices_registry
      label = data['label'] || data[:label] || data['vrn'] || data[:vrn] || logger_id
      registry[logger_id.to_s] = { 'id' => logger_id.to_s, 'label' => label }
      @store.write(registry_key, registry)
    end

    def write_logger_hub(logger_id, hub_id)
      @store.write(logger_hub_key(logger_id), hub_id.to_s)
    end

    def latest_measurement_hub(data)
      measurements = data['m'] || data[:m]
      return nil unless measurements.is_a?(Array) && measurements.any?

      latest = measurements.max_by { |m| measurement_utc(m) }
      latest['hub'] || latest[:hub]
    end

    def measurement_utc(measurement)
      utc = measurement['utc'] || measurement[:utc]
      return 0 if utc.nil?

      utc.to_i
    end
  end
end
