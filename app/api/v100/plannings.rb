require 'coerce'
require 'exceptions'

include PlanningsHelperApi
include PlanningConcern

class V100::Plannings < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def planning_params
      p = ActionController::Parameters.new(params)
      p = p[:planning] if p.key?(:planning)
      p[:zoning_ids] = [p[:zoning_id]] if p[:zoning_id] && (!p[:zoning_ids] || p[:zoning_ids].empty?)
      p[:tag_operation] = p[:tag_operation].prepend('_') if p[:tag_operation] && !p[:tag_operation].start_with('_')
      p.permit(:name, :ref, :date, :begin_date, :end_date, :active, :vehicle_usage_set_id, :tag_operation, tag_ids: [], zoning_ids: [])
    end
  end

  # Planning get is located in plannings_get file because it needs to return specific content types (js, xml and ics)

  resource :plannings do
    desc 'Insert one or more stop into planning routes.',
      detail: 'Insert automatically one or more stops in best routes and on best positions to have minimal influence on route\'s total time (this operation doesn\'t take into account time windows if they exist...). You should use this operation with existing stops in current planning\'s routes. In addition, you should not use this operation with many stops. You should use instead zoning (with automatic clustering creation for instance) to set multiple stops in each available route.',
      nickname: 'automaticInsertStop',
      success: V100::Status.success(:code_201, V100::Entities::Route),
      failure: V100::Status.failures,
      is_array: true
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      requires :stop_ids, type: Array[Integer], desc: 'Ids separated by comma. You should not have too many stops.', documentation: { param_type: 'form' }, coerce_with: CoerceArrayInteger
      optional :max_time, type: Float, desc: 'Maximum time for best routes (in seconds).'
      optional :max_distance, type: Float, desc: 'Maximum distance for best routes (in meters).'
      optional :active_only, type: Boolean, desc: 'Use only active stops.', default: true
      optional :out_of_zone, type: Boolean, desc: 'Take into account points out of zones.', default: true
      optional :with_geojson, type: Symbol, values: [:true, :false, :point, :polyline], default: :false, desc: 'Fill the geojson field with route geometry: `point` to return only points, `polyline` to return with encoded linestring.'
    end
    patch ':id/automatic_insert' do
      Route.includes_destinations.scoping do
        planning = current_customer.plannings.where(ParseIdsRefs.read(params[:id])).first!
        raise Exceptions::JobInProgressError if Job.on_planning(planning.customer.job_optimizer, planning.id)
        stops = planning.routes.flat_map{ |r| r.stops }.select{ |stop| params[:stop_ids].include?(stop.id) }
        begin

          impacted_routes = []
          Planning.transaction do
            stops.each do |stop|
              impacted_routes << (planning.automatic_insert(
                                   stop,
                                   max_time: params[:max_time],
                                   max_distance: params[:max_distance],
                                   out_of_zone: params[:out_of_zone],
                                   active_only: params[:active_only]
                                 ) || raise(Exceptions::LoopError.new))
            end
            impacted_routes.compact!
            impacted_routes.uniq!
            planning.compute
            planning.save!
            present :routes, impacted_routes, with: V100::Entities::Route, geojson: params[:with_geojson]
            status 201
          end
        rescue Exceptions::LoopError => e
          error! V100::Status.code_response(:code_400), 400
        end
      end
    end
  end
end
