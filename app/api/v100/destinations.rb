require 'coerce'
require 'exceptions'

include PlanningsHelperApi
include PlanningConcern

class V100::Destinations < Grape::API
  helpers SharedParams

  resource :plannings do
    params do
      requires :planning_id, type: String, desc: SharedParams::ID_DESC
    end
    segment '/:planning_id' do
      resource :destinations do
        desc 'Compute the minimum detour induced by the insertion of a destination.',
          detail: 'Explore the routes and find a position where the position would have minimal influence on route\'s total time if it were inserted. It returns the potential detour generated (this operation doesn\'t take into account time windows if they exist...).',
          nickname: 'candidateInsertDestination',
          success: V100::Status.success(:code_201, V100::Entities::RouteInsertData),
          failure: V100::Status.failures
        params do
          requires :planning_id, type: String, desc: SharedParams::ID_DESC
          requires :id, type: String, desc: SharedParams::ID_DESC
          optional :max_time, type: Float, desc: 'Maximum time for best routes (in seconds).'
          optional :max_distance, type: Float, desc: 'Maximum distance for best routes (in meters).'
          optional :active_only, type: Boolean, desc: 'Use only active stops.', default: true
          optional :out_of_zone, type: Boolean, desc: 'Take into account points out of zones.', default: true
          optional :with_geojson, type: Symbol, values: [:true, :false, :point, :polyline], default: :false, desc: 'Fill the geojson field with route geometry: `point` to return only points, `polyline` to return with encoded linestring.'
        end
        get ':id/candidate_insert' do
          planning = current_customer.plannings.where(ParseIdsRefs.read(params[:planning_id])).first!
          raise Exceptions::JobInProgressError if Job.on_planning(planning.customer.job_optimizer, planning.id)

          destination = current_customer.destinations.where(ParseIdsRefs.read(params[:id])).first!
          begin
            impacted_routes = []
            Planning.transaction do
              data = planning.candidate_insert(
                destination,
                max_time: params[:max_time],
                max_distance: params[:max_distance],
                out_of_zone: params[:out_of_zone],
                active_only: params[:active_only]
              ) || raise(Exceptions::LoopError.new)
              present data, with: V100::Entities::RouteInsertData, geojson: params[:with_geojson]
              status 201
            end
          end
        end
      end
    end
  end
end
