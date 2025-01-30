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

class V01::DeliverableUnits < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def deliverable_unit_params
      p = ActionController::Parameters.new(params)
      p = p[:deliverable_unit] if p.key?(:deliverable_unit)
      p.permit(:label, :ref, :default_quantity, :optimization_overload_multiplier, :icon)
    end
  end

  resource :deliverable_units do
    desc 'Fetch customer\'s deliverable units. At least one deliverable unit exists per customer. The deliverable unit purposes is to link quantities associated to visits to vehicle capacities.<',
      nickname: 'getDeliverableUnits',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::DeliverableUnit),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[String], desc: 'Select returned deliverable units by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    get do
      deliverable_units = if params.key?(:ids)
                            current_customer.deliverable_units.select { |deliverable_unit| params[:ids].any? { |string| ParseIdsRefs.match(string, deliverable_unit) } }
                          else
                            current_customer.deliverable_units.load
                          end
      present deliverable_units, with: V01::Entities::DeliverableUnit
    end

    desc 'Fetch deliverable unit.',
      nickname: 'getDeliverableUnit',
      success: V01::Status.success(:code_200, V01::Entities::DeliverableUnit),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    get ':id' do
      present current_customer.deliverable_units.find(params[:id]), with: V01::Entities::DeliverableUnit
    end

    desc 'Create deliverable unit.',
      detail: '(Note a default deliverable unit is already automatically created with a customer.) By creating a new deliverable unit, it will be possible to specify quantities and capacities for this another unit.',
      nickname: 'createDeliverableUnit',
      success: V01::Status.success(:code_201, V01::Entities::DeliverableUnit),
      failure: V01::Status.failures
    params do
      use(:request_deliverable_unit)
    end
    post do
      deliverable_unit = current_customer.deliverable_units.build(deliverable_unit_params)
      deliverable_unit.save!
      present deliverable_unit, with: V01::Entities::DeliverableUnit
    end

    desc 'Update deliverable unit.',
      nickname: 'updateDeliverableUnit',
      success: V01::Status.success(:code_200, V01::Entities::DeliverableUnit),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      use(:request_deliverable_unit)
    end
    put ':id' do
      id = ParseIdsRefs.read(params[:id])
      deliverable_unit = current_customer.deliverable_units.where(id).first!
      deliverable_unit.update! deliverable_unit_params
      present deliverable_unit, with: V01::Entities::DeliverableUnit
    end

    desc 'Delete deliverable unit.',
      nickname: 'deleteDeliverableUnit',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    delete ':id' do
      id = ParseIdsRefs.read(params[:id])
      current_customer.deliverable_units.where(id).first!.destroy
      status 204
    end

    desc 'Delete multiple deliverable units.',
      nickname: 'deleteDeliverableUnits',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :ids, type: Array[String], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    delete do
      DeliverableUnit.transaction do
        current_customer.deliverable_units.select do |deliverable_unit|
          params[:ids].any?{ |s| ParseIdsRefs.match(s, deliverable_unit) }
        end.each(&:destroy)
        status 204
      end
    end
  end
end
