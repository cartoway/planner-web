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

  resource :destinations do
    desc 'Fetch customer\'s destinations.',
      nickname: 'getDestinations',
      is_array: true,
      success: V100::Status.success(:code_200, V100::Entities::Destination),
      failure: V100::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[String], desc: 'Select returned destinations by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
      optional :quantities, type: Boolean, default: false, desc: 'Include the quantities when using geojson output.'
      optional :visits, type: Boolean, default: true, desc: 'Include the visits associated to the destinations'
    end
    get do
      if env['api.format'] == :geojson
        present_geojson_destinations params
      else
        destinations =  if params[:visits]
          current_customer.destinations.includes_visits
        else
          current_customer.destinations
        end

        destinations = if params.key?(:ids)
          destinations.select{ |destination|
            params[:ids].any?{ |s| ParseIdsRefs.match(s, destination) }
          }
        else
          destinations.load
        end
        if params[:visits]
          present destinations, with: V100::Entities::DestinationWithVisit
        else
          present destinations, with: V100::Entities::Destination
        end
      end
    end
  end
end
