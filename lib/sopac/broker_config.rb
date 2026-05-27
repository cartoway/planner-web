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
  class BrokerConfig
    class << self
      def for_customer(customer)
        sopac = customer.devices[:sopac] || {}
        from_credentials(
          username: sopac[:username] || sopac['username'],
          password: sopac[:password] || sopac['password'],
          queue_prefix: sopac[:queue_prefix] || sopac['queue_prefix'],
          vhost: sopac[:vhost] || sopac['vhost']
        )
      end

      def from_credentials(credentials)
        credentials = credentials.with_indifferent_access if credentials.respond_to?(:with_indifferent_access)
        {
          host: ENV.fetch('SOPAC_RABBITMQ_HOST', 'rabbitmq-lb.bluconsole.com'),
          vhost: ENV.fetch('SOPAC_RABBITMQ_VHOST', credentials[:vhost].presence || 'blu-vhost'),
          username: credentials[:username],
          password: credentials[:password],
          queue_names: queue_names_from_prefix(normalize_queue_prefix(credentials[:queue_prefix]))
        }
      end

      def customer_enabled?(customer)
        sopac = customer.devices[:sopac]
        return false unless sopac.is_a?(Hash)

        ValueToBoolean.value_to_boolean(sopac[:enable] || sopac['enable']) && valid?(for_customer(customer))
      end

      def valid?(config)
        config[:username].present? &&
          config[:password].present? &&
          config[:queue_names].values.all?(&:present?)
      end

      def normalize_queue_prefix(prefix)
        prefix = prefix.to_s.strip.delete_suffix('/')
        return prefix if prefix.blank?

        normalized = prefix.start_with?('/') ? prefix : "/#{prefix}"
        # BluConsole paths are /ORG/ACCOUNT (e.g. /SOPAC/CARTOWAY). Allow entering only the account slug.
        org_prefix = ENV.fetch('SOPAC_BROKER_ORG_PREFIX', '/SOPAC').delete_suffix('/')
        if org_prefix.present? && normalized.count('/') == 1
          normalized = "#{org_prefix}#{normalized}"
        end
        normalized
      end

      def queue_names_from_prefix(prefix)
        prefix = normalize_queue_prefix(prefix)
        return {} if prefix.blank?

        {
          measurements: "#{prefix}/measurements",
          hubs: "#{prefix}/hubs",
          hubs_gps: "#{prefix}/hubs-gps"
        }
      end
    end
  end
end
