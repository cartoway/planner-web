class V01::Devices::StgTelematics < Grape::API
  namespace :devices do
    namespace :stg_telematics do
      helpers do
        def service
          StgTelematicsService.new customer: @customer
        end
      end

      before do
        @customer = current_customer(params[:customer_id])
      end

      rescue_from DeviceServiceError do |e|
        error! V01::Status.code_response(:code_408, before: e.message), 408
      end

      desc 'List Devices.',
        detail: 'For fleet tracking devices.',
        nickname: 'deviceFleetTrackingList',
        is_array: true,
        success: V01::Status.success(:code_200, V01::Entities::DeviceItem),
        failure: V01::Status.failures(is_array: true)
      get '/devices' do
        present service.list_devices, with: V01::Entities::DeviceItem
      end
    end
  end
end
