class CreateHistoryStops < ActiveRecord::Migration
  def up
    ActiveRecord::Base.connection.execute("
CREATE TABLE IF NOT EXISTS history_stops(
  schema_version character varying NOT NULL,
  date timestamp NOT NULL,
  reseller_id integer NOT NULL,
  customer_id integer NOT NULL,
  vehicle_usage_id integer,
  vehicle_id integer,
  router_mode varchar,
  planning_id integer NOT NULL,
  route_id integer NOT NULL,
  vehicle_usage jsonb,
  vehicle jsonb,
  planning jsonb,
  route jsonb,
  stops jsonb,
  stops_count integer,
  stops_active_count integer
);
CREATE INDEX IF NOT EXISTS stops_idx_customer_id_date ON history_stops(customer_id, date);
ALTER TABLE history_stops ADD CONSTRAINT fk_stops_customer_id FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE;
    ")
  end

  def down
    ActiveRecord::Base.connection.execute("
DROP TABLE IF EXISTS history_stops CASCADE;
    ")
  end
end
