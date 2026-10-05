# frozen_string_literal: true

require 'coerce'

class V01::Operations < Grape::API
  helpers SharedParams
  helpers do
    def find_operation!
      current_customer.operations.find(params[:id])
    end

    def find_operation_route!(operation)
      operation.operation_routes.find(params[:route_id])
    end

    def find_operation_stop!(operation)
      operation.operation_stops.find(params[:stop_id])
    end

    def merge_custom_attributes!(record, incoming)
      return if incoming.blank?

      hash = incoming.respond_to?(:to_unsafe_h) ? incoming.to_unsafe_h : incoming.to_h
      record.update!(custom_attributes: (record.custom_attributes || {}).merge(hash.stringify_keys))
    end

    def save_actual_quantities!(operation_stop, incoming)
      return if incoming.blank?

      stored = (operation_stop.actual_quantities || {}).deep_dup
      hash = incoming.respond_to?(:to_unsafe_h) ? incoming.to_unsafe_h : incoming.to_h
      hash.each do |kind, units|
        kind = kind.to_s
        next unless %w[deliveries pickups].include?(kind)
        next unless units.respond_to?(:each)

        stored[kind] ||= {}
        units.each do |unit_id, value|
          stored[kind][unit_id.to_s] = value.to_s.strip == '' ? nil : value.to_f
        end
      end
      operation_stop.update!(actual_quantities: stored)
    end

    def stash_departure_loading_at!(operation_route, leg, status)
      return unless leg == 'departure'
      return unless status.to_s.downcase == 'finished'
      return unless operation_route.departure_status.to_s.downcase == 'atstore'
      return if operation_route.departure_status_updated_at.blank?

      attrs = (operation_route.custom_attributes || {}).merge(
        '_departure_loading_at' => operation_route.departure_status_updated_at.iso8601
      )
      operation_route.custom_attributes = attrs
    end

    def present_operation_error(exception)
      error!({ message: exception.message, status: 422 }, 422)
    end

    def require_proofs_enabled!
      return if current_customer.enable_proofs?

      error!({ message: I18n.t('stops.mobile.proofs_disabled'), status: 403 }, 403)
    end
  end

  resource :operations do # rubocop:disable Metrics/BlockLength
    desc 'List operations.',
      detail: 'Lists operations for the customer. Filter with status, date, q. Default limit 100.',
      nickname: 'getOperations',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :status, type: String, values: Operation::STATUSES, desc: 'Filter by operation status.'
      optional :date, type: Date, desc: 'Filter by operation date.'
      optional :q, type: String, desc: 'Search in name or ref (ILIKE).'
      optional :limit, type: Integer, default: 100, values: 1..500, desc: 'Max rows (default 100).'
    end
    get do
      authorize!(:read, Operation)
      operations = current_customer.operations.order(date: :desc, id: :desc)
      operations = operations.where(status: params[:status]) if params[:status].present?
      operations = operations.where(date: params[:date]) if params[:date].present?
      if params[:q].present?
        q = "%#{Operation.sanitize_sql_like(params[:q].to_s.strip)}%"
        operations = operations.where('operations.ref ILIKE :q OR operations.name ILIKE :q', q: q)
      end
      present operations.limit(params[:limit]), with: V01::Entities::Operation
    end

    desc 'Search operation stops across operations.',
      detail: 'Cross-operation stop search by destination/store snapshot fields.',
      nickname: 'searchOperationsStops',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::OperationStopSearch),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :q, type: String
      optional :from, type: Date
      optional :to, type: Date
      optional :destination_id, type: Integer
    end
    get 'stops' do
      authorize!(:read, Operation)
      from = params[:from].presence || 90.days.ago.to_date
      to = params[:to].presence || Date.current
      stops = OperationStop.search_by_destination_info(
        query: params[:q],
        from: from,
        to: to,
        include_orphans: true,
        destination_id: params[:destination_id],
        customer_id: current_customer.id
      ).includes(operation_route: :operation).order('operations.date DESC', :index).limit(50)
      present stops, with: V01::Entities::OperationStopSearch
    end

    desc 'Fetch one operation with routes and stops from snapshots.',
      nickname: 'getOperation',
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    get ':id' do
      operation = find_operation!
      authorize!(:read, operation)
      present operation, with: V01::Entities::Operation, type: :full
    end

    desc 'Update operation name or date.',
      nickname: 'updateOperation',
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      optional :name, type: String
      optional :date, type: Date
    end
    patch ':id' do
      operation = find_operation!
      authorize!(:update, operation)
      attrs = {}
      attrs[:name] = params[:name] if params.key?(:name)
      attrs[:date] = params[:date] if params.key?(:date)
      unless operation.update(attrs)
        error!({ message: operation.errors.full_messages.to_sentence, status: 422 }, 422)
      end
      present operation, with: V01::Entities::Operation
    rescue ActiveRecord::RecordNotUnique
      error!({ message: I18n.t('operations.show.date_taken'), status: 422 }, 422)
    end

    desc 'Delete an operation.',
      nickname: 'deleteOperation',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    delete ':id' do
      operation = find_operation!
      authorize!(:destroy, operation)
      operation.destroy!
      status 204
    end

    desc 'Pull telematics stop status into this operation.',
      detail: 'Calls configured devices (TomTom, Praxedo, …) and writes status/ETA/actual quantities on OperationStops.',
      nickname: 'fetchOperationDeviceStatus',
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    post ':id/fetch_device_status' do
      operation = find_operation!
      authorize!(:update, operation)
      DeviceService.new(customer: current_customer).fetch_stops_status(operation)
      status 200
      present operation.reload, with: V01::Entities::Operation, type: :full
    end

    desc 'Resync operation snapshots from its planning.',
      nickname: 'syncOperation',
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      optional :route_ids, type: Array[Integer], coerce_with: CoerceArrayInteger
      optional :stop_ids, type: Array[Integer], coerce_with: CoerceArrayInteger
      optional :orphan_policy, type: Symbol, values: %i[mark cancel], default: :mark
    end
    post ':id/sync' do
      operation = find_operation!
      authorize!(:update, operation)
      planning = operation.planning || raise(ActiveRecord::RecordNotFound)
      Operations::SyncFromPlanning.call(
        planning: planning,
        operation: operation,
        route_ids: params[:route_ids],
        stop_ids: params[:stop_ids],
        orphan_policy: params[:orphan_policy]
      )
      status 200
      present operation.reload, with: V01::Entities::Operation, type: :full
    rescue Operations::EmptyRoutes => e
      present_operation_error(e)
    end

    desc 'Close (historize) an operation.',
      nickname: 'closeOperation',
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    post ':id/close' do
      operation = find_operation!
      authorize!(:update, operation)
      DeliverDemo::Control.stop!(operation)
      operation.update!(status: 'historized', closed_at: Time.current)
      status 200
      present operation, with: V01::Entities::Operation
    end

    desc 'Cancel (historize) an operation.',
      nickname: 'cancelOperation',
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    post ':id/cancel' do
      operation = find_operation!
      authorize!(:update, operation)
      DeliverDemo::Control.stop!(operation)
      operation.update!(status: 'historized', closed_at: Time.current, cancelled_at: Time.current)
      status 200
      present operation, with: V01::Entities::Operation
    end

    desc 'Start Cartoway Deliver demo simulation for an operation.',
      nickname: 'startOperationDemo',
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    post ':id/demo' do
      operation = find_operation!
      authorize!(:update, operation)
      DeliverDemo::Control.start!(operation)
      status 200
      present operation.reload, with: V01::Entities::Operation
    rescue DeliverDemo::Control::NotEnabled
      error!({ message: 'Deliver demo is not enabled', status: 403 }, 403)
    rescue DeliverDemo::Control::NotOpen, DeliverDemo::Control::AlreadyRunning => e
      present_operation_error(e)
    end

    desc 'Stop Cartoway Deliver demo simulation for an operation.',
      nickname: 'stopOperationDemo',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    delete ':id/demo' do
      operation = find_operation!
      authorize!(:update, operation)
      DeliverDemo::Control.stop!(operation)
      status 204
    end

    desc 'Reset Cartoway Deliver demo execution state for an operation.',
      nickname: 'resetOperationDemo',
      success: V01::Status.success(:code_200, V01::Entities::Operation),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    post ':id/demo/reset' do
      operation = find_operation!
      authorize!(:update, operation)
      DeliverDemo::Control.reset!(operation)
      status 200
      present operation.reload, with: V01::Entities::Operation
    rescue DeliverDemo::Control::NotEnabled
      error!({ message: 'Deliver demo is not enabled', status: 403 }, 403)
    rescue DeliverDemo::Control::NotOpen => e
      present_operation_error(e)
    end

    desc 'GeoJSON map payload for an operation.',
      nickname: 'getOperationMap',
      success: V01::Status.success(:code_200),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    get ':id/map' do
      operation = find_operation!
      authorize!(:read, operation)
      routes = operation.operation_routes.active_sync.includes(:operation_stops, :vehicle_positions, route: :route_geojson).to_a
      Operations::MapGeojson.call(operation: operation, routes: routes)
    end

    desc 'Search stops within one operation.',
      nickname: 'searchOperationStops',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::OperationStopSearch),
      failure: V01::Status.failures(is_array: true)
    params do
      requires :id, type: Integer
      optional :q, type: String
    end
    get ':id/search_stops' do
      operation = find_operation!
      authorize!(:read, operation)
      stops = operation.operation_stops.executable
      if params[:q].present?
        escaped = "%#{OperationStop.sanitize_sql_like(params[:q].strip)}%"
        stops = stops.where(<<~SQL.squish, q: escaped)
          destination_snapshot->>'name' ILIKE :q
          OR destination_snapshot->>'ref' ILIKE :q
          OR destination_snapshot->>'street' ILIKE :q
          OR destination_snapshot->>'city' ILIKE :q
          OR store_snapshot->>'name' ILIKE :q
        SQL
      end
      present stops.order(:index).limit(50), with: V01::Entities::OperationStopSearch
    end

    desc 'Fetch one operation stop.',
      nickname: 'getOperationStop',
      success: V01::Status.success(:code_200, V01::Entities::OperationStop),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :stop_id, type: Integer
      optional :with_events, type: Boolean, default: false
      optional :with_media, type: Boolean, default: false
    end
    get ':id/stops/:stop_id' do
      operation = find_operation!
      authorize!(:read, operation)
      stop = find_operation_stop!(operation)
      stop = operation.operation_stops.includes(:operation_stop_status_events).with_attached_photos.with_attached_signature.find(stop.id)
      present stop, with: V01::Entities::OperationStop, with_events: params[:with_events], with_media: params[:with_media]
    end

    desc 'Update operation stop quantities or custom attributes.',
      nickname: 'updateOperationStop',
      success: V01::Status.success(:code_200, V01::Entities::OperationStop),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :stop_id, type: Integer
      optional :actual_quantities, type: Hash
      optional :custom_attributes, type: Hash
      optional :status, type: String, desc: 'Optional status reset/update (creates an event).'
      optional :recorded_at, type: DateTime
      optional :eta, type: DateTime
    end
    patch ':id/stops/:stop_id' do
      operation = find_operation!
      authorize!(:update, operation)
      stop = find_operation_stop!(operation)
      save_actual_quantities!(stop, params[:actual_quantities])
      merge_custom_attributes!(stop, params[:custom_attributes])
      if params.key?(:status)
        OperationStops::RecordStatus.call(
          operation_stop: stop,
          status: params[:status],
          eta: params[:eta],
          recorded_at: params[:recorded_at].presence || Time.current,
          source: 'api'
        )
      end
      present stop.reload, with: V01::Entities::OperationStop
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
      operation = find_operation!
      authorize!(:update, operation)
      operation_stop = find_operation_stop!(operation)
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

    desc 'Attach photos to an operation stop.',
      nickname: 'createOperationStopPhotos',
      success: V01::Status.success(:code_201, V01::Entities::OperationStop),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :stop_id, type: Integer
      requires :photos, type: Array[File], desc: 'Image files.'
    end
    post ':id/stops/:stop_id/photos' do
      operation = find_operation!
      authorize!(:update, operation)
      require_proofs_enabled!
      stop = find_operation_stop!(operation)
      unless stop.attach_photos(params[:photos])
        error!({ message: stop.errors.full_messages.to_sentence.presence || 'photo upload failed', status: 422 }, 422)
      end
      status 201
      present stop.reload, with: V01::Entities::OperationStop, with_media: true
    end

    desc 'Delete a photo from an operation stop.',
      nickname: 'deleteOperationStopPhoto',
      success: V01::Status.success(:code_200, V01::Entities::OperationStop),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :stop_id, type: Integer
      requires :photo_id, type: Integer
    end
    delete ':id/stops/:stop_id/photos/:photo_id' do
      operation = find_operation!
      authorize!(:update, operation)
      stop = find_operation_stop!(operation)
      attachment = stop.photos_attachments.find_by(id: params[:photo_id]) ||
                   stop.photos_attachments.find_by!(blob_id: params[:photo_id])
      unless stop.destroy_photo(attachment)
        error!({ message: I18n.t('stops.mobile.photos_delete_expired'), status: 403 }, 403)
      end
      present stop.reload, with: V01::Entities::OperationStop, with_media: true
    end

    desc 'Attach a signature to an operation stop.',
      nickname: 'createOperationStopSignature',
      success: V01::Status.success(:code_201, V01::Entities::OperationStop),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :stop_id, type: Integer
      requires :signature, type: File
    end
    post ':id/stops/:stop_id/signature' do
      operation = find_operation!
      authorize!(:update, operation)
      require_proofs_enabled!
      stop = find_operation_stop!(operation)
      unless stop.attach_signature(params[:signature])
        error!({ message: stop.errors.full_messages.to_sentence.presence || 'signature upload failed', status: 422 }, 422)
      end
      status 201
      present stop.reload, with: V01::Entities::OperationStop, with_media: true
    end

    desc 'Update departure or arrival status on an operation route.',
      nickname: 'updateOperationRouteStatus',
      success: V01::Status.success(:code_200, V01::Entities::OperationRoute),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :route_id, type: Integer
      requires :leg, type: String, values: %w[departure arrival]
      optional :status, type: String
      optional :status_updated_at, type: DateTime
      optional :custom_attributes, type: Hash
    end
    patch ':id/routes/:route_id/status' do
      operation = find_operation!
      authorize!(:update, operation)
      route = find_operation_route!(operation)
      if params.key?(:status)
        leg = params[:leg]
        status_value = params[:status].presence
        recorded_at = params[:status_updated_at].presence || Time.current
        stash_departure_loading_at!(route, leg, status_value)
        route.update!(
          "#{leg}_status" => status_value,
          "#{leg}_status_updated_at" => recorded_at
        )
      end
      merge_custom_attributes!(route, params[:custom_attributes])
      present route.reload, with: V01::Entities::OperationRoute
    end

    desc 'Record a vehicle position for an operation route.',
      nickname: 'updateOperationRoutePosition',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :route_id, type: Integer
      requires :lat, type: Float
      requires :lng, type: Float
      requires :positioned_at, type: DateTime
      optional :heading, type: Float
      optional :speed, type: Float
      optional :accuracy, type: Float
      optional :altitude, type: Float
    end
    patch ':id/routes/:route_id/position' do
      operation = find_operation!
      authorize!(:update, operation)
      route = find_operation_route!(operation)
      VehiclePositions::Record.call(
        operation_route: route,
        lat: params[:lat],
        lng: params[:lng],
        positioned_at: params[:positioned_at],
        source: 'api',
        heading: params[:heading],
        speed: params[:speed],
        accuracy: params[:accuracy],
        altitude: params[:altitude],
        payload: {}
      )
      status 204
    rescue VehiclePositions::Record::MissingPositionedAt, VehiclePositions::Record::OperationNotOpen => e
      present_operation_error(e)
    end

    desc 'Transfer an operation stop to another route of the same operation.',
      nickname: 'transferOperationStop',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :route_id, type: Integer
      requires :stop_id, type: Integer
      requires :target_operation_route_id, type: Integer
      optional :recorded_at, type: DateTime
    end
    patch ':id/routes/:route_id/transfer_stop' do
      operation = find_operation!
      authorize!(:update, operation)
      route = find_operation_route!(operation)
      operation_stop = route.operation_stops.find(params[:stop_id])
      target = operation.operation_routes.planned.find(params[:target_operation_route_id])
      OperationStops::Transfer.call(
        operation_stop: operation_stop,
        target_operation_route: target,
        recorded_at: params[:recorded_at].presence || Time.current,
        source: 'api'
      )
      status 204
    rescue OperationStops::Transfer::Error => e
      present_operation_error(e)
    end

    desc 'List proof media (photos/signatures) for an operation route.',
      nickname: 'getOperationRouteMedia',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::OperationMediaGroup),
      failure: V01::Status.failures(is_array: true)
    params do
      requires :id, type: Integer
      requires :route_id, type: Integer
    end
    get ':id/routes/:route_id/media' do
      operation = find_operation!
      authorize!(:read, operation)
      route = find_operation_route!(operation)
      stops = route.operation_stops.executable
                   .with_attached_photos
                   .with_attached_signature
                   .order(:index)
      groups = stops.filter_map { |stop|
        documents = stop.document_items
        next if documents.empty?

        { stop: stop, documents: documents }
      }
      present groups, with: V01::Entities::OperationMediaGroup
    end
  end
end
