require 'coerce'

class V01::Devices::Deliver < Grape::API
  PLANNING_GONE = 'Gone. Deliver no longer targets planning routes. Use operation_id / operation_route_id on these endpoints, or POST /operations/:id/transmit.'.freeze

  namespace :devices do
    namespace :deliver do

      helpers do
        def find_operation!
          @customer.operations.find(params[:operation_id])
        end

        def find_operation_route!
          OperationRoute.joins(:operation).merge(@customer.operations).find(params[:operation_route_id])
        end

        def planned_routes(operation)
          routes = operation.operation_routes.planned.where.not(vehicle_id: nil)
          return routes unless params[:route_ids].present?

          routes.where(id: params[:route_ids])
        end

        def transmit_routes!(operation, routes)
          error!({ message: 'Operation is not open.', status: 422 }, 422) unless operation.open?

          Operations::TransmitRoutes.call(
            operation: operation,
            routes: routes.to_a,
            channel: params[:channel]
          )
          present Array(routes).map(&:reload), with: V01::Entities::DeviceRouteLastSentAt
        end

        def clear_sent!(routes)
          list = Array(routes)
          list.each do |route|
            route.update_columns(last_sent_at: nil, last_sent_to: nil, updated_at: Time.current)
          end
          present list, with: V01::Entities::DeviceRouteLastSentAt
        end
      end

      before do
        @customer = current_customer(params[:customer_id])
      end

      rescue_from DeviceServiceError do |e|
        error! V01::Status.code_response(:code_408, before: e.message), 408
      end

      desc 'Send one operation route to the driver (email/SMS).',
        detail: 'Targets an OperationRoute. Prefer POST /operations/:id/transmit for bulk. Optional channel=email|sms.',
        nickname: 'deviceDeliverSend',
        success: V01::Status.success(:code_201, V01::Entities::DeviceRouteLastSentAt),
        failure: V01::Status.failures(add: [:code_422])
      params do
        requires :operation_route_id, type: Integer, desc: 'OperationRoute ID'
        optional :channel, type: String, values: %w[email sms], documentation: { desc: 'Limit to one channel. Omit for both when enabled.' }
      end
      post '/send' do
        operation_route = find_operation_route!
        transmit_routes!(operation_route.operation, [operation_route])
      end

      desc 'Send all planned routes of an operation to drivers (email/SMS).',
        detail: 'Targets an Operation. Same behaviour as POST /operations/:id/transmit. Optional channel and route_ids (OperationRoute ids).',
        nickname: 'deviceDeliverSendMultiple',
        success: V01::Status.success(:code_201, V01::Entities::DeviceRouteLastSentAt),
        failure: V01::Status.failures(add: [:code_422])
      params do
        requires :operation_id, type: Integer, desc: 'Operation ID'
        optional :channel, type: String, values: %w[email sms], documentation: { desc: 'Limit to one channel. Omit for both when enabled.' }
        optional :route_ids, type: Array[Integer], coerce_with: CoerceArrayInteger, documentation: { desc: 'Optional OperationRoute ids subset.' }
      end
      post '/send_multiple' do
        operation = find_operation!
        transmit_routes!(operation, planned_routes(operation))
      end

      desc 'Clear last_sent on one operation route.',
        detail: 'Clears last_sent_at/last_sent_to on the OperationRoute (does not push GPS devices).',
        nickname: 'deviceDeliverClear',
        success: V01::Status.success(:code_200, V01::Entities::DeviceRouteLastSentAt),
        failure: V01::Status.failures
      params do
        requires :operation_route_id, type: Integer, desc: 'OperationRoute ID'
      end
      delete '/clear' do
        clear_sent!(find_operation_route!)
      end

      desc 'Clear last_sent on all planned routes of an operation.',
        detail: 'Clears last_sent_at/last_sent_to on planned OperationRoutes.',
        nickname: 'deviceDeliverClearMultiple',
        success: V01::Status.success(:code_200, V01::Entities::DeviceRouteLastSentAt),
        failure: V01::Status.failures
      params do
        requires :operation_id, type: Integer, desc: 'Operation ID'
      end
      delete '/clear_multiple' do
        operation = find_operation!
        clear_sent!(operation.operation_routes.planned.to_a)
      end
    end
  end
end
