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

require 'bunny'

module SopacBroker
  class BrokerConnection
    # Auth + temperatures only need measurements; hubs/gps may be provisioned later by BluConsole.
    REQUIRED_QUEUE_KIND = :measurements

    class << self
      def connect(config)
        raise DeviceServiceError, 'Sopac : broker configuration is incomplete' unless BrokerConfig.valid?(config)

        Bunny.new(connection_options(config)).start
      end

      def verify!(config)
        results = diagnose(config)
        required_name = config[:queue_names][REQUIRED_QUEUE_KIND]
        required = results.find { |r| r[:resource] == 'queue' && r[:name] == required_name }

        if required.nil? || !required[:ok]
          error = required&.dig(:error) || 'NOT_FOUND'
          raise DeviceServiceError,
                "Sopac : required queue not found (#{required_name}: #{error}). " \
                'Ask BluConsole/SOPAC to enable the broker for this organization.'
        end

        optional_missing = results.reject { |r| r[:ok] }.reject { |r| r[:name] == required_name }
        return if optional_missing.empty?

        names = optional_missing.select { |r| r[:resource] == 'queue' }.map { |r| r[:name] }.uniq
        Rails.logger.warn("[SopacBroker] optional broker queues not yet available: #{names.join(', ')}")
      end

      # One channel per probe: RabbitMQ closes the channel after a passive declare NOT_FOUND.
      def diagnose(config)
        results = []
        connection = nil
        begin
          connection = connect(config)
          config[:queue_names].each do |kind, name|
            results << probe_on(connection, resource: :queue, name: name, label: kind.to_s)
            results << probe_on(connection, resource: :exchange, name: name, label: "#{kind} (exchange)")
          end
        rescue Bunny::AuthenticationFailureError
          raise DeviceServiceError, 'Sopac : invalid broker credentials'
        rescue Bunny::TCPConnectionFailed, Bunny::NetworkFailure => e
          raise DeviceServiceError, "Sopac : #{e.message}"
        rescue OpenSSL::SSL::SSLError => e
          raise DeviceServiceError, "Sopac : SSL error (#{e.message})"
        ensure
          connection&.close if connection&.open?
        end
        results
      end

      def probe_on(connection, resource:, name:, label:)
        channel = connection.create_channel
        probe(channel, resource: resource, name: name, label: label)
      ensure
        channel.close if channel&.open?
      end

      def probe(channel, resource:, name:, label:)
        case resource
        when :queue
          q = channel.queue(name, passive: true)
          {
            label: label,
            resource: 'queue',
            name: name,
            ok: true,
            messages: q.message_count,
            consumers: q.consumer_count
          }
        when :exchange
          channel.exchange(name, passive: true)
          { label: label, resource: 'exchange', name: name, ok: true }
        end
      rescue Bunny::NotFound
        { label: label, resource: resource.to_s, name: name, ok: false, error: 'NOT_FOUND' }
      rescue Bunny::AccessRefused => e
        { label: label, resource: resource.to_s, name: name, ok: false, error: "ACCESS_REFUSED (#{e.message})" }
      rescue StandardError => e
        { label: label, resource: resource.to_s, name: name, ok: false, error: "#{e.class}: #{e.message}" }
      end

      private

      def connection_options(config)
        {
          host: config[:host],
          vhost: config[:vhost],
          username: config[:username],
          password: config[:password],
          automatically_recover: true,
          tls: true,
          tls_silence_warnings: true
        }
      end
    end
  end
end
