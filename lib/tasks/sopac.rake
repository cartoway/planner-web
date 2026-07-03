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

namespace :sopac do
  namespace :broker do
    desc 'Run SOPAC RabbitMQ consumer (long-running process)'
    task run: :environment do
      require Rails.root.join('lib/sopac/broker_consumer')
      SopacBroker::BrokerConsumer.new.run
    end

    desc 'Check BluConsole broker connectivity and queue/exchange names. ' \
         'Usage: rake sopac:broker:check[customer_id] OR USERNAME=... PASSWORD=... QUEUE_PREFIX=... rake sopac:broker:check'
    task :check, [:customer_id] => :environment do |_t, args|
      require Rails.root.join('lib/sopac/broker_connection')

      config =
        if args[:customer_id].present?
          customer = Customer.find(args[:customer_id])
          puts "Customer ##{customer.id} (#{customer.name})"
          SopacBroker::BrokerConfig.for_customer(customer)
        else
          SopacBroker::BrokerConfig.from_credentials(
            username: ENV['USERNAME'] || ENV.fetch('SOPAC_USERNAME', nil),
            password: ENV['PASSWORD'] || ENV.fetch('SOPAC_PASSWORD', nil),
            queue_prefix: ENV['QUEUE_PREFIX'] || ENV.fetch('SOPAC_QUEUE_PREFIX', nil)
          )
        end

      unless SopacBroker::BrokerConfig.valid?(config)
        abort 'Missing username, password or queue_prefix (pass customer id or ENV vars).'
      end

      puts "Host: #{config[:host]}  Vhost: #{config[:vhost]}  User: #{config[:username]}"
      puts "Queue prefix resolves to:"
      config[:queue_names].each { |kind, name| puts "  #{kind}: #{name}" }
      puts

      results = SopacBroker::BrokerConnection.diagnose(config)
      results.each do |r|
        status = r[:ok] ? 'OK' : 'FAIL'
        extra = []
        extra << "messages=#{r[:messages]}" if r.key?(:messages)
        extra << "consumers=#{r[:consumers]}" if r.key?(:consumers)
        extra << r[:error] if r[:error]
        puts "[#{status}] #{r[:resource].ljust(8)} #{r[:name]}  #{extra.join(' ')}"
      end

      required = config[:queue_names][:measurements]
      required_ok = results.any? { |r| r[:ok] && r[:resource] == 'queue' && r[:name] == required }
      optional_missing = results.reject { |r| r[:ok] }.reject { |r| r[:name] == required }

      unless required_ok
        abort "Required queue missing: #{required}. Ask BluConsole/SOPAC to enable the broker for this organization."
      end

      if optional_missing.any?
        puts "\nOptional queues/exchanges not yet provisioned (GPS/hubs features unavailable until BluConsole creates them):"
        optional_missing.each { |r| puts "  - #{r[:name]} (#{r[:error]})" }
      else
        puts "\nAll probed resources exist."
      end
    end
  end
end
