require 'coerce'
require 'exceptions'

class V100::Routes < Grape::API
  helpers SharedParams

  resource :plannings do
    params do
      requires :planning_id, type: String, desc: SharedParams::ID_DESC
    end
    segment '/:planning_id' do
      resource :routes do
        desc 'Move stop(s) to route. Append in order at end if automatic_insert is false.',
          detail: 'Set a new A route (or vehicle) for a stop which was in a previous B route in the same planning.',
          nickname: 'moveStops',
          success: V100::Status.success(:code_204),
          failure: V100::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          requires :stop_ids, type: Array[Integer], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', documentation: {param_type: 'form'}, coerce_with: CoerceArrayString
        end
        patch ':id/stops/moves' do
          Route.includes_destinations_and_stores.scoping do
            planning = current_customer.plannings.where(ParseIdsRefs.read(params[:planning_id])).first!
            raise Exceptions::JobInProgressError if Job.on_planning(planning.customer.job_optimizer, planning.id)

            route = planning.routes.includes_destinations_and_stores.where(ParseIdsRefs.read(params[:id])).first!
            moving_stops = planning.routes.includes_destinations_and_stores.flat_map{ |r| r.stops }.select{ |stop| params[:stop_ids].include?(stop.id) }
            unless moving_stops.empty?
              begin
                Planning.transaction do
                  Optimizer.optimize(planning, route, { insertion_only: true, moving_stop_ids: moving_stops.map(&:id) })
                  current_customer.save!
                end
              rescue VRPNoSolutionError
                error! V100::Status.code_response(:code_304), 304
              end
              if planning.customer.job_optimizer
                present planning.customer.job_optimizer, with: V100::Entities::Job
              else
                status 204
              end
            end
          rescue Exceptions::JobInProgressError
            status 409
            present planning.customer.job_optimizer, with: V100::Entities::Job, message: I18n.t('errors.planning.already_optimizing')
          end
        end

        desc 'Move visit(s) to route. Append in order at end if automatic_insert is false.',
          detail: 'Set a new A route (or vehicle) for a visit which was in a previous B route in the same planning. Automatic_insert parameter allows to compute index of the stops created for visits.',
          nickname: 'moveVisits',
          success: V100::Status.success(:code_204),
          failure: V100::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          requires :visit_ids, types: [Array[String], Array[Integer]], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', documentation: {param_type: 'form'}, coerce_with: CoerceArrayString
        end
        patch ':id/visits/moves' do
          Route.includes_destinations_and_stores.scoping do
            planning = current_customer.plannings.where(ParseIdsRefs.read(params[:planning_id])).first!
            raise Exceptions::JobInProgressError if Job.on_planning(planning.customer.job_optimizer, planning.id)

            route = planning.routes.includes_destinations_and_stores.where(ParseIdsRefs.read(params[:id])).first!
            visit_ids = params[:visit_ids].map{ |raw_id|
              id_hash = ParseIdsRefs.read(raw_id)
              id_hash[:ref] || id_hash[:id]
            }.compact
            moving_stops = planning.routes.includes_destinations_and_stores.flat_map{ |r| r.stops }.select{ |stop| stop.is_a?(StopVisit) && visit_ids.include?(stop.visit.id) }

            unless moving_stops.empty?
              begin
              Planning.transaction do
                Optimizer.optimize(planning, route, { insertion_only: true, moving_stop_ids: moving_stops.map(&:id) })
                current_customer.save!
              end
              rescue VRPNoSolutionError
                error! V100::Status.code_response(:code_304), 304
              end
              if planning.customer.job_optimizer
                present planning.customer.job_optimizer, with: V100::Entities::Job
              else
                status 204
              end
            end
          rescue Exceptions::JobInProgressError
            status 409
            present planning.customer.job_optimizer, with: V100::Entities::Job, message: I18n.t('errors.planning.already_optimizing')
          end
        end

        desc 'Add intermediate store to route. Append in order at the end of the route',
          detail: 'Set a new StopStore to the route. index parameter allows to insert the stop at the provided index in the route.',
          nickname: 'addStopStore',
          success: V100::Status.success(:code_204),
          failure: V100::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          requires :index, type: Integer
        end
        post ':route_id/stores/:id' do
          error!(V100::Status.code_response(:code_401, after: I18n.t('errors.routes.enable_store_stops')), 401) if !current_customer.enable_store_stops

          Route.includes_destinations_and_stores.scoping do
            planning = current_customer.plannings.where(ParseIdsRefs.read(params[:planning_id])).first!
            raise Exceptions::JobInProgressError if Job.on_planning(planning.customer.job_optimizer, planning.id)

            route = planning.routes.includes_destinations_and_stores.where(ParseIdsRefs.read(params[:route_id])).first!
            store = current_customer.stores.where(ParseIdsRefs.read(params[:id])).first!

            Planning.transaction do
              route.add_store(store, params[:index])
              route.compute_saved
              current_customer.save!
            end
          rescue Exceptions::JobInProgressError
            status 409
            present planning.customer.job_optimizer, with: V100::Entities::Job, message: I18n.t('errors.planning.already_optimizing')
          end
        end
      end
    end
  end
end
