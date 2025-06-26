require 'exceptions'

class V100::Stops < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def stop_params
      p = ActionController::Parameters.new(params)
      p.permit(:active)
    end
  end

  resource :plannings do
    params do
      requires :planning_id, type: Integer
    end
    segment '/:planning_id' do

      resource :routes do
        params do
          requires :route_id, type: Integer
        end
        segment '/:route_id' do

          resource :stops do
            desc 'Delete stop. This operation is only allowed for StopStores.',
              nickname: 'deleteStop',
              success: V100::Status.success(:code_200, V100::Entities::Stop),
              failure: V100::Status.failures
            params do
              requires :id, type: Integer
            end
            delete ':id' do
              planning = current_customer.plannings.where(ParseIdsRefs.read(params[:planning_id])).first!
              raise Exceptions::JobInProgressError if Job.on_planning(current_customer.job_optimizer, planning.id)
              route = planning.routes.find{ |route| route.id == Integer(params[:route_id]) } || raise(ActiveRecord::RecordNotFound.new)
              stop = route.stops.find{ |stop| stop.id == Integer(params[:id]) } || raise(ActiveRecord::RecordNotFound.new)
              Planning.transaction do
                route.remove_store(stop)
                route.compute_saved
                current_customer.save!
              end
              status 204
            rescue Exceptions::JobInProgressError
              status 409
              present planning.customer.job_optimizer, with: V100::Entities::Job, message: I18n.t('errors.planning.already_optimizing')
            end
          end
        end
      end
    end
  end
end
