class V01::Devices::Deliver < Grape::API
  namespace :devices do
    namespace :deliver do

      helpers do
        def service
          DeliverService.new customer: @customer
        end
      end

      before do
        @customer = current_customer(params[:customer_id])
      end

      rescue_from DeviceServiceError do |e|
        error! e.message, 200
      end

      desc 'Send Planning Routes.',
        detail: 'On Cartoway Deliver.',
        nickname: 'deviceDeliverSendMultiple',
        success: V01::Status.success(:code_201),
        failure: V01::Status.failures
      params do
        requires :planning_id, type: Integer, desc: 'Planning ID'
      end
      post '/send_multiple' do
        device_send_routes
      end

      desc 'Clear Route.',
        detail: 'On Cartoway Deliver.',
        nickname: 'deviceDeliverClear',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      params do
        requires :route_id, type: Integer, desc: 'Route ID'
      end
      delete '/clear' do
        device_clear_route
      end

      desc 'Clear multiple routes.',
        detail: 'On Cartoway Deliver.',
        nickname: 'deviceDeliverClearMultiple',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      params do
        requires :planning_id, type: Integer, desc: 'Planning ID'
      end
      delete '/clear_multiple' do
        device_clear_routes
      end
    end
  end
end
