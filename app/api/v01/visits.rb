# Copyright © Mapotempo, 2016
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
require 'coerce'

class V01::Visits < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def visit_params
      p = ActionController::Parameters.new(params)
      p = p[:visit] if p.key?(:visit)

      # Deals with deprecated quantity
      unless p[:quantities]
        p[:quantities] = {current_customer.deliverable_units[0].id.to_s => p.delete(:quantity)} if p[:quantity] && current_customer.deliverable_units.size > 0
        if p[:quantity1_1] || p[:quantity1_2]
          p[:quantities] = {}
          p[:quantities].merge!({current_customer.deliverable_units[0].id.to_s => p.delete(:quantity1_1)}) if p[:quantity1_1] && current_customer.deliverable_units.size > 0
          p[:quantities].merge!({current_customer.deliverable_units[1].id.to_s => p.delete(:quantity1_2)}) if p[:quantity1_2] && current_customer.deliverable_units.size > 1
        end
      end
      # Serialize quantities
      if p[:quantities]
        p[:quantities] = p[:quantities].reject { |q| q.blank? }
        if p[:quantities].empty?
          p.delete(:quantities)
        else
          p[:quantities_operations] = Hash[p[:quantities].map{ |q| [q[:deliverable_unit_id].to_s, q[:operation]] }]
          p[:quantities] = Hash[p[:quantities].map{ |q| [q[:deliverable_unit_id].to_s, q[:quantity]] }]
        end
      end

      #Deals with deprecated schedule params
      p[:time_window_start_1] ||= p.delete(:open1) if p[:open1]
      p[:time_window_end_1] ||= p.delete(:close1) if p[:close1]
      p[:time_window_start_2] ||= p.delete(:open2) if p[:open2]
      p[:time_window_end_2] ||= p.delete(:close2) if p[:close2]

      deliverable_unit_ids = current_customer.deliverable_units.map{ |du| du.id.to_s }
      nested_visit_custom_attributes = current_customer.custom_attributes.select(&:visit?).map(&:name)

      p.permit(:ref, :duration, :time_window_start_1, :time_window_end_1, :time_window_start_2, :time_window_end_2, :priority, :force_position, tag_ids: [], quantities: deliverable_unit_ids, quantities_operations: deliverable_unit_ids, custom_attributes: nested_visit_custom_attributes)
    end
  end

  resource :destinations do
    params do
      requires :destination_id, type: String, desc: SharedParams::ID_DESC
    end
    segment '/:destination_id' do

      resource :visits do
        desc 'Fetch destination\'s visits.',
        nickname: 'getVisits',
        is_array: true,
        success: V01::Status.success(:code_200, V01::Entities::Visit),
        failure: V01::Status.failures(is_array: true)
        params do
          optional :ids, type: Array[String], desc: 'Select returned visits by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
        end
        get do
          destination_id = ParseIdsRefs.read(params[:destination_id])
          visits = if params.key?(:ids)
            current_customer.destinations.includes_visits.where(destination_id).first!.visits.select{ |visit|
              params[:ids].any?{ |s| ParseIdsRefs.match(s, visit) }
            }
          else
            current_customer.destinations.includes_visits.where(destination_id).first!.visits.load
          end
          present visits, with: V01::Entities::Visit
        end

        desc 'Fetch visit.',
          nickname: 'getVisit',
          success: V01::Status.success(:code_200, V01::Entities::Visit),
          failure: V01::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
        end
        get ':id' do
          destination_id = ParseIdsRefs.read(params[:destination_id])
          id = ParseIdsRefs.read(params[:id])
          present current_customer.destinations.includes_visits.where(destination_id).first!.visits.where(id).first!, with: V01::Entities::Visit
        end

        desc 'Fetch visit stops.',
          nickname: 'getVisitStops',
          is_array: true,
          success: V01::Entities::Stop
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
        end
        get ':id/stops' do
          destination_id = ParseIdsRefs.read(params[:destination_id])
          id = ParseIdsRefs.read(params[:id])
          present current_customer.destinations.includes_visits.where(destination_id).first!.visits.where(id).first!.stop_visits, with: V01::Entities::Stop
        end

        desc 'Create visit.',
          nickname: 'createVisit',
          success: V01::Status.success(:code_201, V01::Entities::Visit),
          failure: V01::Status.failures
        params do
          use :request_visit
        end
        post do
          raise Exceptions::JobInProgressError if current_customer.job_optimizer

          destination_id = ParseIdsRefs.read(params[:destination_id])
          destination = current_customer.destinations.where(destination_id).first!
          visit = destination.visits.build(visit_params)
          visit.save!
          destination.customer.save!
          present visit, with: V01::Entities::Visit
        end

        desc 'Update visit.',
          detail: 'If want to force geocoding for a new address, you have to send empty lat/lng with new address.',
          nickname: 'updateVisit',
          success: V01::Status.success(:code_200, V01::Entities::Visit),
          failure: V01::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          use :request_visit
        end
        put ':id' do
          raise Exceptions::JobInProgressError if current_customer.job_optimizer

          destination_id = ParseIdsRefs.read(params[:destination_id])
          id = ParseIdsRefs.read(params[:id])
          destination = current_customer.destinations.where(destination_id).first!
          visit = destination.visits.where(id).first!
          visit.update! visit_params
          destination.customer.save!
          present visit, with: V01::Entities::Visit
        end

        desc 'Delete visit.',
          nickname: 'deleteVisit',
          success: V01::Status.success(:code_204),
          failure: V01::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
        end
        delete ':id' do
          raise Exceptions::JobInProgressError if current_customer.job_optimizer

          destination_id = ParseIdsRefs.read(params[:destination_id])
          id = ParseIdsRefs.read(params[:id])
          destination = current_customer.destinations.where(destination_id).first!
          destination.visits.where(id).first!.destroy
          destination.customer.save!
          status 204
        end
      end
    end
  end

  resource :visits do
    desc 'Update multiple visits.',
      nickname: 'updateVisits'
    params do
      requires :ids, type: Array[String], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
      optional :tag_ids, type: Array[Integer], desc: 'Ids separated by comma.', coerce_with: CoerceArrayInteger, documentation: { param_type: 'form' }
    end
    put do
      Visit.transaction do
        raise Exceptions::JobInProgressError if current_customer.job_optimizer

        visits = current_customer.visits.select{ |visit|
          params[:ids].any?{ |s| ParseIdsRefs.match(s, visit) }
        }.each{ |visit|
          visit.assign_attributes(tag_ids: params[:tag_ids])
          visit.save!
        }
        present visits, with: V01::Entities::Visit
      end
    end

    desc 'Delete multiple visits.',
      nickname: 'deleteVisits',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      optional :ids, type: Array[String], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    delete do
      raise Exceptions::JobInProgressError if current_customer.job_optimizer

      Visit.transaction do
        if params[:ids] && !params[:ids].empty?
          visits = current_customer.visits.select { |visit|
            params[:ids].any? { |s| ParseIdsRefs.match(s, visit) }
          }

          if current_customer.visits.count == visits.count
            current_customer.delete_all_visits
          else
            visits.each(&:destroy)
          end
        else
          current_customer.delete_all_visits
        end

        status 204
      end
    end
  end
end
