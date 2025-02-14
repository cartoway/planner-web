class AddVehicleDriverToken < ActiveRecord::Migration
  require 'jwt'

  def up
    add_column :vehicles, :driver_token, :string, uniq: true
    generate_token
  end

  def down
    remove_column :vehicles, :driver_token
  end

  def generate_token
    Vehicle.find_each{ |vehicle|
      vehicle.update_columns(driver_token: JWT.encode({ vehicle_id: vehicle.id }, Planner::Application.config.secret_key_base, 'HS256'))
    }
  end
end
