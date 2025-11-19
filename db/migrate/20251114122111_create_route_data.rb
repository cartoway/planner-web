class CreateRouteData < ActiveRecord::Migration[6.1]
  def up
    create_table :route_data do |t|
      t.float :distance
      t.float :emission
      t.float :cost_distance
      t.float :cost_fixed
      t.float :cost_time
      t.float :revenue
      t.integer :start
      t.integer :end
      t.integer :drive_time
      t.integer :wait_time
      t.integer :visits_duration
      t.jsonb :pickups, default: {}
      t.jsonb :deliveries, default: {}
      t.integer :departure
      t.string :status
      t.time :eta
      t.timestamps null: true
    end

    add_column :routes, :route_data_id, :integer
    add_foreign_key :routes, :route_data, column: :route_data_id, primary_key: :id, on_delete: :cascade
    add_column :routes, :start_route_data_id, :integer
    add_foreign_key :routes, :route_data, column: :start_route_data_id, on_delete: :cascade
    add_column :routes, :stop_route_data_id, :integer
    add_foreign_key :routes, :route_data, column: :stop_route_data_id, on_delete: :cascade
    add_column :stops, :route_data_id, :integer
    add_foreign_key :stops, :route_data, column: :route_data_id, on_delete: :cascade

    StopStore.all.find_each do |stop_store|
      stop_store.route_data = RouteData.create!
      stop_store.save!
    end

    Route.find_in_batches(batch_size: 100) do |routes_batch|
      routes_batch.each do |route|
        route_data = RouteData.create!(
          distance: route.read_attribute(:distance),
          emission: route.read_attribute(:emission),
          cost_distance: route.read_attribute(:cost_distance),
          cost_fixed: route.read_attribute(:cost_fixed),
          cost_time: route.read_attribute(:cost_time),
          revenue: route.read_attribute(:revenue),
          start: route.read_attribute(:start),
          end: route.read_attribute(:end),
          drive_time: route.read_attribute(:drive_time),
          wait_time: route.read_attribute(:wait_time),
          visits_duration: route.read_attribute(:visits_duration),
          pickups: route.read_attribute(:pickups) || {},
          deliveries: route.read_attribute(:deliveries) || {},
          departure: route.read_attribute(:departure)
        )
        start_route_data = RouteData.create!(
          status: route.read_attribute(:departure_status),
          eta: route.read_attribute(:departure_eta)
        )
        stop_route_data = RouteData.create!(
          status: route.read_attribute(:arrival_status),
          eta: route.read_attribute(:arrival_eta)
        )
        route.update_columns(
          route_data_id: route_data.id,
          start_route_data_id: start_route_data.id,
          stop_route_data_id: stop_route_data.id,
          outdated: true
        )
      end
    end

    remove_column :routes, :distance
    remove_column :routes, :emission
    remove_column :routes, :cost_distance
    remove_column :routes, :cost_fixed
    remove_column :routes, :cost_time
    remove_column :routes, :revenue
    remove_column :routes, :start
    remove_column :routes, :end
    remove_column :routes, :drive_time
    remove_column :routes, :wait_time
    remove_column :routes, :visits_duration
    remove_column :routes, :pickups
    remove_column :routes, :deliveries
    remove_column :routes, :departure
    remove_column :routes, :departure_status
  end

  def down
    add_column :routes, :distance, :float
    add_column :routes, :emission, :float
    add_column :routes, :cost_distance, :float
    add_column :routes, :cost_fixed, :float
    add_column :routes, :cost_time, :float
    add_column :routes, :revenue, :float
    add_column :routes, :start, :integer
    add_column :routes, :end, :integer
    add_column :routes, :drive_time, :integer
    add_column :routes, :wait_time, :integer
    add_column :routes, :visits_duration, :integer
    add_column :routes, :pickups, :jsonb, default: {}
    add_column :routes, :deliveries, :jsonb, default: {}
    add_column :routes, :departure, :integer
    add_column :routes, :departure_status, :string

    migrate_data_down

    # Remove foreign key constraints before dropping the table
    remove_foreign_key :routes, :route_data if foreign_key_exists?(:routes, :route_data, column: :route_data_id)
    remove_foreign_key :routes, :route_data if foreign_key_exists?(:routes, :route_data, column: :start_route_data_id)
    remove_foreign_key :routes, :route_data if foreign_key_exists?(:routes, :route_data, column: :stop_route_data_id)
    remove_foreign_key :stops, :route_data if foreign_key_exists?(:stops, :route_data, column: :route_data_id)

    # Remove columns that reference route_data
    remove_column :routes, :route_data_id if column_exists?(:routes, :route_data_id)
    remove_column :routes, :start_route_data_id if column_exists?(:routes, :start_route_data_id)
    remove_column :routes, :stop_route_data_id if column_exists?(:routes, :stop_route_data_id)
    remove_column :stops, :route_data_id if column_exists?(:stops, :route_data_id)

    drop_table :route_data
  end

  def migrate_data_down
    # Migrate data back from route_data table in batches
    batch_size = 100
    Route.find_in_batches(batch_size: batch_size) do |routes_batch|
      routes_batch.each do |route|
        if route.route_data
          route.update_columns(
            distance: route.route_data.distance,
            emission: route.route_data.emission,
            cost_distance: route.route_data.cost_distance,
            cost_fixed: route.route_data.cost_fixed,
            cost_time: route.route_data.cost_time,
            revenue: route.route_data.revenue,
            start: route.route_data.start,
            end: route.route_data.end,
            drive_time: route.route_data.drive_time,
            wait_time: route.route_data.wait_time,
            visits_duration: route.route_data.visits_duration,
            pickups: route.route_data.pickups,
            deliveries: route.route_data.deliveries,
            departure: route.route_data.departure,
            departure_status: route.start_route_data.status,
            departure_eta: route.start_route_data.eta,
            arrival_status: route.stop_route_data.status,
            arrival_eta: route.stop_route_data.eta
          )
        end
      end
    end
  end
end
