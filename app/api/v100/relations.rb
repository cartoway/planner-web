require 'coerce'

class V100::Relations < Grape::API
  helpers SharedParams
  helpers do
    def session
      env[Rack::RACK_SESSION]
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def relation_params
      p = ActionController::Parameters.new(params)

      p.permit(:relation_type, :current_id, :successor_id)
    end
  end

  resource :relations do
    desc 'Fetch relations',
      nickname: 'getRelations',
      is_array: true,
      success: V100::Status.success(:code_200, V100::Entities::Relation),
      failure: V100::Status.failures(is_array: true, override: {code_404: 'Relations not found.'})
    params do
      optional :ids, type: Array[Integer], desc: 'Select returned relations by id.', coerce_with: CoerceArrayInteger
    end
    get do
      relations =
        if params.key?(:ids)
          current_customer.stops_relations.select{ |relation| params[:ids].any? { |string| relation.id == string }}
        else
          current_customer.stops_relations.load
        end
      if relations
        present relations, with: V100::Entities::Relation
      else
        error! V100::Status.code_response(:code_404, before: 'Relation'), 404
      end
    end

    desc 'Fetch relation.',
      nickname: 'getRelation',
      success: V100::Status.success(:code_200, V100::Entities::Relation),
      failure: V100::Status.failures(override: {code_404: 'Relation not found.'})
    params do
      requires :id, type: Integer
    end
    get ':id' do
      relation = current_customer.stops_relations.where(id: params[:id]).first
      if relation
        present relation, with: V100::Entities::Relation
        return
      end
      error! V100::Status.code_response(:code_404, before: 'Relation'), 404
    end

    desc 'Update relation.',
      nickname: 'updateRelation',
      success: V100::Status.success(:code_200, V100::Entities::Relation),
      failure: V100::Status.failures(override: {code_404: 'Relation not found.' })
    params do
      requires :id, type: Integer
      use :request_relation
    end
    put ':id' do
      relation = current_customer.stops_relations.where(id: params[:id]).first
      current = current_customer.visits.where(id: params[:current_id]).first if params[:current_id]
      successor = current_customer.visits.where(id: params[:successor_id]).first if params[:successor_id_id]
      if relation
        relation.update! relation_params
        present relation, with: V100::Entities::Relation
        return
      end
      error! V100::Status.code_response(:code_404, before: 'Relation'), 404
    end

    desc 'Create relation.',
      nickname: 'CreateRelation',
      success: V100::Status.success(:code_200, V100::Entities::Relation),
      failure: V100::Status.failures
    params do
      use(:request_relation, relation_post: true)
    end
    post do
      current = current_customer.visits.where(id: params[:current_id]).first
      successor = current_customer.visits.where(id: params[:successor_id]).first
      if current && successor
        relation = current_customer.stops_relations.build(relation_params)
        relation.save!
        current_customer.save!
        present relation, with: V100::Entities::Relation
        return
      end
      error! V100::Status.code_response(:code_404, before: 'Relation'), 404
    end

    desc 'Delete relation.',
      nickname: 'deleteRelation',
      success: V100::Status.success(:code_204),
      failure: V100::Status.failures
    params do
      requires :id, type: Integer
    end
    delete ':id' do
      id = ParseIdsRefs.read(params[:id])
      current_customer.stops_relations.where(id).first!.destroy
      status 204
    end
  end
end
