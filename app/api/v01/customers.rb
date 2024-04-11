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

class V01::Customers < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def customer_params
      p = ActionController::Parameters.new(params)
      p = p[:customer] if p.key?(:customer)

      customer = @current_user.admin? && params[:id] ? @current_user.reseller.customers.where(ParseIdsRefs.read(params[:id])).first! : @current_user.customer

      # Deals with deprecated speed_multiplicator
      p[:speed_multiplier] = p.delete[:speed_multiplicator] if p[:speed_multiplicator]
      p[:visit_duration] = p.delete(:take_over) if p[:take_over]

      p[:devices] = customer[:devices].deep_merge(p[:devices] || {}) if customer && customer[:devices].size > 0

      if @current_user.admin?
        p.permit(
          :reseller_id,
          :ref,
          :name,
          :description,
          :end_subscription,
          :test,
          :visit_duration,
          :default_country,
          :with_state,
          :max_vehicles,
          :max_plannings,
          :max_zonings,
          :max_destinations,
          :max_vehicle_usage_sets,
          #:enable_orders,
          :enable_references,
          :enable_multi_visits,
          :enable_global_optimization,
          :enable_vehicle_position,
          :enable_stop_status,
          :enable_sms,
          :sms_template,
          :sms_concat,
          :sms_from_customer_name,
          :enable_external_callback,
          :external_callback_url,
          :external_callback_name,
          :optimization_max_split_size,
          :optimization_cluster_size,
          :optimization_time,
          :optimization_stop_soft_upper_bound,
          :optimization_vehicle_soft_upper_bound,
          :optimization_cost_waiting_time,
          :optimization_force_start,
          :print_planning_annotating,
          :print_header,
          :print_map,
          :print_stop_time,
          :print_barcode,
          :profile_id,
          :router_id,
          :router_dimension,
          :speed_multiplier,
          router_options: [:time, :distance, :isochrone, :isodistance, :traffic, :avoid_zones, :track, :motorway, :toll, :trailers, :weight, :weight_per_axle, :height, :width, :length, :hazardous_goods, :max_walk_distance, :approach, :snap, :strict_restriction],
          advanced_options: permit_recursive_params(p[:advanced_options]),
          devices: permit_recursive_params(p[:devices]))
      else
        p.permit(
          :visit_duration,
          :default_country,
          :optimization_max_split_size,
          :optimization_cluster_size,
          :optimization_time,
          :optimization_stop_soft_upper_bound,
          :optimization_vehicle_soft_upper_bound,
          :optimization_cost_waiting_time,
          :optimization_force_start,
          :print_planning_annotating,
          :print_header,
          :print_map,
          :print_stop_time,
          :print_barcode,
          :sms_template,
          :sms_concat,
          :sms_from_customer_name,
          :enable_external_callback,
          :external_callback_url,
          :external_callback_name,
          :router_id,
          :router_dimension,
          :speed_multiplier,
          router_options: [:time, :distance, :isochrone, :isodistance, :traffic, :avoid_zones, :track, :motorway, :toll, :trailers, :weight, :weight_per_axle, :height, :width, :length, :hazardous_goods, :max_walk_distance, :approach, :snap, :strict_restriction],
          advanced_options: permit_recursive_params(p[:advanced_options]),
          devices: permit_recursive_params(p[:devices]))
      end
    end

    def permit_recursive_params(params)
      if !params.nil?
        params.map do |key, value|
          if value.is_a?(Array)
            { key => [ permit_recursive_params(value.first) ] }
          elsif value.is_a?(Hash) || value.is_a?(ActionController::Parameters)
            { key => permit_recursive_params(value) }
          elsif value.present?
            key
          end
        end
      end
    end
  end

  resource :customers do
    desc 'Fetch customer accounts (admin).',
      detail: 'Retrieve all customer accounts. Only available with an admin api_key.',
      is_array: true,
      nickname: 'getCustomers',
      success: V01::Status.success(:code_200, V01::Entities::CustomerAdmin),
      failure: V01::Status.failures(is_array: true)
    get do
      if @current_user.admin?
        present @current_user.reseller.customers, with: V01::Entities::CustomerAdmin
      else
        error! V01::Status.code_response(:code_403), 403
      end
    end

    desc 'Fetch customer account.',
      detail: 'Get informations and details, for example customer account associated to the current api_key.',
      nickname: 'getCustomer',
      success: V01::Status.success(:code_200, V01::Entities::CustomerAdmin),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    get ':id' do
      if @current_user.admin?
        customer = @current_user.reseller.customers.where(ParseIdsRefs.read(params[:id])).first!
        present customer, with: V01::Entities::CustomerAdmin
      elsif ParseIdsRefs.match params[:id], @current_customer
        present @current_customer, with: V01::Entities::Customer
      else
        error! V01::Status.code_response(:code_404, before: 'Customer'), 404
      end
    end

    desc 'Fetch users for customer account id.',
      nickname: 'getCustomerUsers',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::User),
      failure: V01::Status.failures(is_array: true)
    params do
    end
    get ':id/users' do
      if @current_user.admin?
        customer = @current_user.reseller.customers.where(ParseIdsRefs.read(params[:id])).first!
        present customer.users, whith: V01::Entities::User
      else
        error! V01::Status.code_response(:code_403), 403
      end
    end

    desc 'Update customer account.',
      detail: 'Update informations and details, for example customer account associated to the current api_key.',
      nickname: 'updateCustomer',
      success: V01::Status.success(:code_200, V01::Entities::CustomerAdmin),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      use :request_customer
    end
    put ':id' do
      if @current_user.admin?
        customer = @current_user.reseller.customers.where(ParseIdsRefs.read(params[:id])).first!
        customer.update! customer_params
        present customer, with: V01::Entities::CustomerAdmin
      elsif ParseIdsRefs.match params[:id], @current_customer
        @current_customer.update! customer_params
        present @current_customer, with: V01::Entities::Customer
      else
        error! V01::Status.code_response(:code_404, before: 'Customer'), 404
      end
    end

    desc 'Create customer account (admin).',
      detail: 'Only available with an admin api_key.',
      nickname: 'createCustomer',
      success: V01::Status.success(:code_201, V01::Entities::CustomerAdmin),
      failure: V01::Status.failures
    params do
      use(:request_customer, required_customer_params: true)
    end
    post do
      if @current_user.admin?
        customer = @current_user.reseller.customers.build(customer_params)
        @current_user.reseller.save!
        present customer, with: V01::Entities::CustomerAdmin
      else
        error! V01::Status.code_response(:code_403), 403
      end
    end

    desc 'Delete customer account (admin).',
      detail: 'Only available with an admin api_key.',
      nickname: 'deleteCustomer',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    delete ':id' do
      if @current_user.admin?
        id = ParseIdsRefs.read(params[:id])
        @current_user.reseller.customers.where(id).first!.destroy
        status 204
      else
        error! V01::Status.code_response(:code_403), 403
      end
    end

    desc 'Return a job.',
      detail: 'Return asynchronous job (like geocoding, optimizer) currently runned for the customer.',
      nickname: 'getJob',
      success: V01::Status.success(:code_200),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      requires :job_id, type: Integer
    end
    get ':id/job/:job_id' do
      customer = @current_user.admin? ?
        @current_user.reseller.customers.where(ParseIdsRefs.read(params[:id])).first! :
        ParseIdsRefs.match(params[:id], @current_customer) ? @current_customer : nil
      if customer
        if customer.job_optimizer && customer.job_optimizer_id == params[:job_id]
          customer.job_optimizer
        elsif customer.job_destination_geocoding && customer.job_destination_geocoding_id == params[:job_id]
          customer.job_destination_geocoding
        elsif customer.job_store_geocoding && customer.job_store_geocoding_id == params[:job_id]
          customer.job_store_geocoding
        end
      else
        error! V01::Status.code_response(:code_404, before: 'Customer'), 404
      end
    end

    desc 'Cancel job.',
      detail: 'Cancel asynchronous job (like geocoding, optimizer) currently runned for the customer.',
      nickname: 'deleteJob',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      requires :job_id, type: Integer
    end
    delete ':id/job/:job_id' do
      customer = @current_user.admin? ?
        @current_user.reseller.customers.where(ParseIdsRefs.read(params[:id])).first! :
        ParseIdsRefs.match(params[:id], @current_customer) ? @current_customer : nil
      if customer
        if customer.job_optimizer && customer.job_optimizer_id == params[:job_id]
          # Secure condition to avoid deleting job while in transmission
          raise Exceptions::JobInTransmissionError if !customer.job_optimizer.locked_at.nil? && !customer.job_optimizer.progress['job_id']

          Optimizer.kill_optimize(customer.job_optimizer.progress['job_id'])
          customer.job_optimizer.destroy
        elsif customer.job_destination_geocoding && customer.job_destination_geocoding_id == params[:job_id]
          customer.job_destination_geocoding.destroy
        elsif customer.job_store_geocoding && customer.job_store_geocoding_id == params[:job_id]
          customer.job_store_geocoding.destroy
        end
        status 204
      else
        error! V01::Status.code_response(:code_404, before: 'Customer'), 404
      end
    rescue Exceptions::JobInTransmissionError
      status 409
      present planning.customer.job_optimizer, with: V01::Entities::Job, message: I18n.t('errors.planning.transmission_in_progress')
    end

    desc 'Duplicate customer.',
      detail: 'Create a copy of customer. Only available with an admin api_key.',
      nickname: 'duplicateCustomer',
      success: V01::Status.success(:code_201, V01::Entities::CustomerAdmin),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      optional :exclude_users, type: Boolean, default: false
    end
    patch ':id/duplicate' do
      if @current_user.admin?
        customer = @current_user.reseller.customers.where(ParseIdsRefs.read(params[:id])).first!
        customer.exclude_users = params[:exclude_users]
        customer = customer.duplicate
        customer.save! validate: Mapotempo::Application.config.validate_during_duplication

        present customer, with: V01::Entities::CustomerAdmin
      else
        error! V01::Status.code_response(:code_403), 403
      end
    end
  end
end
