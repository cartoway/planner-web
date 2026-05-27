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
  # Discover logger IDs by sampling the measurements queue without consuming messages
  # (nack + requeue). Used when opening the vehicle form before the long-running consumer
  # has populated the Redis registry.
  class RegistryBootstrap
    MAX_MESSAGES = 500
    THROTTLE_SECONDS = 60

    class << self
      def call(customer)
        return {} unless BrokerConfig.customer_enabled?(customer)

        cache = Cache.new(customer.id)
        registry = cache.devices_registry
        return registry if registry.any?
        return registry if throttled?(customer.id)

        populate_from_queue(customer)
        mark_attempted(customer.id)
        Cache.new(customer.id).devices_registry
      rescue Bunny::NotFound => e
        Rails.logger.warn("[SopacBroker::RegistryBootstrap] measurements queue not found: #{e.message}")
        {}
      rescue DeviceServiceError, Bunny::AuthenticationFailureError => e
        Rails.logger.warn("[SopacBroker::RegistryBootstrap] skipped: #{e.message}")
        {}
      rescue Bunny::TCPConnectionFailed, Bunny::NetworkFailure, OpenSSL::SSL::SSLError => e
        Rails.logger.warn("[SopacBroker::RegistryBootstrap] connection error: #{e.message}")
        {}
      end

      private

      def populate_from_queue(customer)
        config = BrokerConfig.for_customer(customer)
        connection = BrokerConnection.connect(config)
        channel = connection.create_channel
        queue = channel.queue(config[:queue_names][:measurements], passive: true)
        count = 0

        loop do
          delivery_info, _properties, body = queue.pop(manual_ack: true)
          break if delivery_info.nil? || count >= MAX_MESSAGES

          MessageHandlers::Measurement.call(customer.id, body)
          channel.nack(delivery_info.delivery_tag, false, true)
          count += 1
        end

        Rails.logger.info(
          "[SopacBroker::RegistryBootstrap] customer #{customer.id}: sampled #{count} measurement message(s)"
        )
      ensure
        channel&.close if channel&.open?
        connection&.close if connection&.open?
      end

      def throttle_key(customer_id)
        "sopac:customer:#{customer_id}:registry_bootstrap_at"
      end

      def throttled?(customer_id)
        store = Planner::Application.config.devices.sopac_cache_object
        last = store.read(throttle_key(customer_id))
        last.present? && last > THROTTLE_SECONDS.seconds.ago
      end

      def mark_attempted(customer_id)
        Planner::Application.config.devices.sopac_cache_object.write(
          throttle_key(customer_id),
          Time.current
        )
      end
    end
  end
end
