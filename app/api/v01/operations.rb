# frozen_string_literal: true

class V01::Operations < Grape::API
  helpers SharedParams

  resource :operations do
    desc 'List operations.',
      nickname: 'getOperations',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures(is_array: true)
    get do
      authorize!(:read, Operation)
      operations = current_customer.operations.order(date: :desc, id: :desc).limit(100)
      present operations, with: V01::Entities::Operation
    end

    desc 'Fetch one operation with routes and stops from snapshots.',
      nickname: 'getOperation',
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    get ':id' do
      operation = current_customer.operations.find(params[:id])
      authorize!(:read, operation)
      present operation, with: V01::Entities::Operation, type: :full
    end

    desc 'Append a stop status event. Does not move the cursor when recorded_at is older.',
      nickname: 'postOperationStopStatus',
      success: V01::Status.success(:code_201, V01::Entities::OperationStop),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :stop_id, type: Integer
      requires :status, type: String
      requires :recorded_at, type: DateTime
      optional :eta, type: DateTime
    end
    post ':id/stops/:stop_id/status' do
      operation = current_customer.operations.find(params[:id])
      authorize!(:update, operation)
      operation_stop = operation.operation_stops.find(params[:stop_id])
      result = OperationStops::RecordStatus.call(
        operation_stop: operation_stop,
        status: params[:status],
        eta: params[:eta],
        recorded_at: params[:recorded_at],
        source: 'api'
      )
      status 201
      present result[:operation_stop], with: V01::Entities::OperationStop, cursor_updated: result[:cursor_updated]
    end
  end
end
