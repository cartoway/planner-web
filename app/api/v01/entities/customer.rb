# Copyright © Mapotempo, 2014-2015
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class V01::Entities::Customer < Grape::Entity
  def self.entity_name
    'V01_Customer'
  end
  EDIT_ONLY_ADMIN = 'Only available in admin.'.freeze

  expose(:id, documentation: { type: Integer })
  expose(:end_subscription, documentation: { type: Date, desc: EDIT_ONLY_ADMIN })
  expose(:max_vehicles, documentation: { type: Integer, desc: EDIT_ONLY_ADMIN })

  # Default
  expose(:store_ids, documentation: { type: Integer, is_array: true })
  expose(:vehicle_usage_set_ids, documentation: { type: Integer, is_array: true })
  expose(:deliverable_unit_ids, documentation: { type: Integer, is_array: true })

  expose(:ref, documentation: { type: String, desc: EDIT_ONLY_ADMIN })
  expose(:name, documentation: { type: String, desc: EDIT_ONLY_ADMIN })
  expose(:visit_duration, documentation: { type: DateTime, desc: 'Visit duration' }) { |m| m.visit_duration_time_with_seconds }
  expose(:default_country, documentation: { type: String })
  expose(:router_id, documentation: { type: Integer })
  expose(:router_dimension, documentation: { type: String, values: ::Router::DIMENSION.keys })
  expose(:router_options, using: V01::Entities::RouterOptions, documentation: { type: V01::Entities::RouterOptions })
  expose(:speed_multiplier, documentation: { type: Float })
  expose(:history_cron_hour, documentation: { type: Integer })

  expose(:print_planning_annotating, documentation: { type: 'Boolean' })
  expose(:print_header, documentation: { type: String })
  expose(:print_barcode, documentation: { type: String, values: ::Customer::PRINT_BARCODE, desc: 'Print the Reference as Barcode'})
  expose(:sms_template, documentation: { type: String })
  expose(:sms_concat, documentation: { type: 'Boolean' })
  expose(:sms_from_customer_name, documentation: { type: 'Boolean' })

  expose(:optimization_max_split_size, documentation: { type: Integer, desc: 'Maximum number of visits to split problem', default: Mapotempo::Application.config.optimize_max_split_size })
  expose(:optimization_cluster_size, documentation: { type: Integer, desc: 'Time in seconds to group near visits', default: Mapotempo::Application.config.optimize_cluster_size })
  expose(:optimization_time, documentation: { type: Float, desc: 'Maximum optimization time (by vehicle)', default: Mapotempo::Application.config.optimize_time })
  expose(:optimization_minimal_time, documentation: { type: Float, desc: 'Minimum optimization time (by vehicle)', default: Mapotempo::Application.config.optimize_minimal_time })
  expose(:optimization_stop_soft_upper_bound, documentation: { type: Float, desc: 'Stops delay coefficient, 0 to avoid delay', default: Mapotempo::Application.config.optimize_stop_soft_upper_bound })
  expose(:optimization_vehicle_soft_upper_bound, documentation: { type: Float, desc: 'Vehicles delay coefficient, 0 to avoid delay', default: Mapotempo::Application.config.optimize_vehicle_soft_upper_bound })
  expose(:optimization_cost_waiting_time, documentation: { type: Float, desc: 'Coefficient to manage waiting time', default: Mapotempo::Application.config.optimize_cost_waiting_time })
  expose(:optimization_force_start, documentation: { type: 'Boolean', desc: 'Force time for departure', default: Mapotempo::Application.config.optimize_force_start })

  expose(:advanced_options, documentation: { type: String, desc: 'Advanced options in a serialized json format' })

  expose(:job_destination_geocoding_id, documentation: { type: Integer })
  expose(:job_store_geocoding_id, documentation: { type: Integer })
  expose(:job_optimizer_id, documentation: { type: Integer })

  expose(:devices, documentation: { type: Hash, desc: EDIT_ONLY_ADMIN })

  # Deprecated fields
  expose(:take_over, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `visit_duration` instead' }) { |m| m.visit_duration_time_with_seconds }
  expose(:speed_multiplicator, documentation: { hidden: true, type: Float, desc: 'Deprecated, use speed_multiplier instead.' }) { |m| m.speed_multiplier }
end
