class V01::Devices::Planner < Grape::API
  namespace :devices do
    namespace :planner do

      helpers do
        def service
          PlannerService.new customer: @customer
        end
      end

      before do
        @customer = current_customer(params[:customer_id])
      end

      rescue_from DeviceServiceError do |e|
        error! e.message, 200
      end

      desc 'Send Planning Routes.',
        detail: 'On Cartoway Mobile.',
        nickname: 'devicePlannerSendMultiple',
        success: V01::Status.success(:code_201),
        failure: V01::Status.failures
      params do
        requires :planning_id, type: Integer, desc: 'Planning ID'
      end
      post '/send_multiple' do
        device_send_routes
      end
    end
  end
end
