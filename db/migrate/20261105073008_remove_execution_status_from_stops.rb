# frozen_string_literal: true

# Execution status/ETA/transmit cursor live on operation_stops / operation_routes.
# Legacy planning stops.status(+updated_at)/eta, route_data depot status/eta,
# leftover routes arrival_* / departure_eta, and routes.last_sent_* were
# backfilled by Operations::BackfillFromPastPlannings before this drop.
class RemoveExecutionStatusFromStops < ActiveRecord::Migration[6.1]
  def up
    # history_live_routes selects routes.* so PG tracks a dependency on these columns
    execute 'DROP VIEW IF EXISTS history_live_routes CASCADE'

    remove_column :stops, :status, :string if column_exists?(:stops, :status)
    remove_column :stops, :status_updated_at, :datetime if column_exists?(:stops, :status_updated_at)
    remove_column :stops, :eta, :datetime if column_exists?(:stops, :eta)

    remove_column :route_data, :status, :string if column_exists?(:route_data, :status)
    remove_column :route_data, :eta, :time if column_exists?(:route_data, :eta)

    remove_column :routes, :arrival_status, :string if column_exists?(:routes, :arrival_status)
    remove_column :routes, :arrival_eta, :time if column_exists?(:routes, :arrival_eta)
    remove_column :routes, :departure_eta, :time if column_exists?(:routes, :departure_eta)
    remove_column :routes, :last_sent_at, :datetime if column_exists?(:routes, :last_sent_at)
    remove_column :routes, :last_sent_to, :string if column_exists?(:routes, :last_sent_to)

    recreate_history_live_routes
  end

  def down
    execute 'DROP VIEW IF EXISTS history_live_routes CASCADE'

    add_column :stops, :status, :string unless column_exists?(:stops, :status)
    add_column :stops, :status_updated_at, :datetime unless column_exists?(:stops, :status_updated_at)
    add_column :stops, :eta, :datetime unless column_exists?(:stops, :eta)

    add_column :route_data, :status, :string unless column_exists?(:route_data, :status)
    add_column :route_data, :eta, :time unless column_exists?(:route_data, :eta)

    add_column :routes, :arrival_status, :string unless column_exists?(:routes, :arrival_status)
    add_column :routes, :arrival_eta, :time unless column_exists?(:routes, :arrival_eta)
    add_column :routes, :departure_eta, :time unless column_exists?(:routes, :departure_eta)
    add_column :routes, :last_sent_at, :datetime unless column_exists?(:routes, :last_sent_at)
    add_column :routes, :last_sent_to, :string unless column_exists?(:routes, :last_sent_to)

    recreate_history_live_routes
  end

  private

  def recreate_history_live_routes
    view_sql_path = Rails.root.join('docker/superset/history_live_routes.sql')
    execute File.read(view_sql_path) if File.exist?(view_sql_path)
  end
end
