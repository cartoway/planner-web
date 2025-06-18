namespace :counters do
  desc "Reset all customer counters (destinations, visits, plannings, vehicles)"
  task reset: :environment do
    puts "Starting counter reset for all customers..."

    Customer.reset_column_information
    total_customers = Customer.count
    batch_size = 100
    total_batches = (total_customers.to_f / batch_size).ceil

    puts "Found #{total_customers} customers to process in #{total_batches} batches of #{batch_size}"

    processed_count = 0
    updated_count = 0

    Customer.find_in_batches(batch_size: batch_size).with_index do |batch, batch_index|
      print "\rProcessing batch #{batch_index + 1}/#{total_batches} (#{processed_count}/#{total_customers} customers processed)"

      batch_updates = []

      batch.each do |customer|
        actual_destinations = customer.destinations.count
        actual_visits = Visit.joins(:destination).where(destinations: { customer_id: customer.id }).count
        actual_plannings = customer.plannings.count
        actual_vehicles = customer.vehicles.count

        if customer.destinations_count != actual_destinations ||
           customer.visits_count != actual_visits ||
           customer.plannings_count != actual_plannings ||
           customer.vehicles_count != actual_vehicles

          batch_updates << {
            id: customer.id,
            destinations_count: actual_destinations,
            visits_count: actual_visits,
            plannings_count: actual_plannings,
            vehicles_count: actual_vehicles
          }
        end

        processed_count += 1
      end

      # Bulk update for this batch
      if batch_updates.any?
        batch_updates.each do |update|
          Customer.where(id: update[:id]).update_all(
            destinations_count: update[:destinations_count],
            visits_count: update[:visits_count],
            plannings_count: update[:plannings_count],
            vehicles_count: update[:vehicles_count]
          )
        end
        updated_count += batch_updates.count
      end
    end

    puts "\nCounter reset completed successfully!"
    puts "Processed #{processed_count} customers, updated #{updated_count} customers"
  end

  desc "Reset counters for a specific customer by ID"
  task :reset_customer, [:customer_id] => :environment do |task, args|
    customer_id = args[:customer_id]

    unless customer_id
      puts "Error: Please provide a customer ID"
      puts "Usage: rake counters:reset_customer[123]"
      exit 1
    end

    customer = Customer.find_by(id: customer_id)

    unless customer
      puts "Error: Customer with ID #{customer_id} not found"
      exit 1
    end

    puts "Resetting counters for customer: #{customer.name} (ID: #{customer.id})"

    destinations_count = customer.destinations.count
    visits_count = Visit.joins(:destination).where(destinations: { customer_id: customer.id }).count
    plannings_count = customer.plannings.count
    vehicles_count = customer.vehicles.count

    Customer.where(id: customer.id).update_all(
      destinations_count: destinations_count,
      visits_count: visits_count,
      plannings_count: plannings_count,
      vehicles_count: vehicles_count
    )

    puts "Counter reset completed for customer #{customer.name}!"
    puts "  - Destinations: #{destinations_count}"
    puts "  - Visits: #{visits_count}"
    puts "  - Plannings: #{plannings_count}"
    puts "  - Vehicles: #{vehicles_count}"
  end

  desc "Check counter consistency for all customers"
  task check: :environment do
    puts "Checking counter consistency for all customers..."

    Customer.reset_column_information
    total_customers = Customer.count
    batch_size = 100
    total_batches = (total_customers.to_f / batch_size).ceil

    puts "Found #{total_customers} customers to check in #{total_batches} batches of #{batch_size}"

    processed_count = 0
    inconsistent_customers = []

    Customer.find_in_batches(batch_size: batch_size).with_index do |batch, batch_index|
      print "\rChecking batch #{batch_index + 1}/#{total_batches} (#{processed_count}/#{total_customers} customers checked)"

      batch.each do |customer|
        actual_destinations = customer.destinations.count
        actual_visits = Visit.joins(:destination).where(destinations: { customer_id: customer.id }).count
        actual_plannings = customer.plannings.count
        actual_vehicles = customer.vehicles.count

        if customer.destinations_count != actual_destinations ||
           customer.visits_count != actual_visits ||
           customer.plannings_count != actual_plannings ||
           customer.vehicles_count != actual_vehicles

          inconsistent_customers << {
            id: customer.id,
            name: customer.name,
            destinations: { stored: customer.destinations_count, actual: actual_destinations },
            visits: { stored: customer.visits_count, actual: actual_visits },
            plannings: { stored: customer.plannings_count, actual: actual_plannings },
            vehicles: { stored: customer.vehicles_count, actual: actual_vehicles }
          }
        end

        processed_count += 1
      end
    end

    puts "\n\nCounter consistency check completed!"

    if inconsistent_customers.empty?
      puts "All counters are consistent!"
    else
      puts "Found #{inconsistent_customers.count} customers with inconsistent counters:"

      inconsistent_customers.each do |customer|
        puts "\nCustomer: #{customer[:name]} (ID: #{customer[:id]})"

        if customer[:destinations][:stored] != customer[:destinations][:actual]
          puts "  - Destinations: stored=#{customer[:destinations][:stored]}, actual=#{customer[:destinations][:actual]}"
        end

        if customer[:visits][:stored] != customer[:visits][:actual]
          puts "  - Visits: stored=#{customer[:visits][:stored]}, actual=#{customer[:visits][:actual]}"
        end

        if customer[:plannings][:stored] != customer[:plannings][:actual]
          puts "  - Plannings: stored=#{customer[:plannings][:stored]}, actual=#{customer[:plannings][:actual]}"
        end

        if customer[:vehicles][:stored] != customer[:vehicles][:actual]
          puts "  - Vehicles: stored=#{customer[:vehicles][:stored]}, actual=#{customer[:vehicles][:actual]}"
        end
      end

      puts "\nRun 'rake counters:reset' to fix all inconsistencies"
    end
  end
end
