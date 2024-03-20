class DeviceExpiredTokenError < StandardError
end

#RestClient.log = 'stdout'

class StgTelematics < DeviceBase
  def definition
    {
      device: 'stg_telematics',
      label: 'STG Telematics',
      label_small: 'STG',
      route_operations: [],
      has_sync: true,
      help: true,
      forms: {
        settings: {
          company_names: :text, # FIXME: parameters are sent at root level in api...
          username: :text,
          password: :password
        },
        vehicle: {
          stg_telematics_vehicle_id: :select
        },
      }
    }
  end

  def check_auth(params)
    authenticate(nil, params.symbolize_keys)
  end

  def authenticate(customer, params)
    response = get_access_token(params || customer.devices[:stg_telematics])
    body = JSON.parse(response.body)
    if response.code == 200 && body['result'] == 1
      return JSON.parse(response.body)&.dig('data', 'token')
    else
      raise DeviceServiceError.new('STG Telematics: %s' % [I18n.t('errors.stg_telematics.get_access_token')])
    end
  rescue RestClient::Forbidden, RestClient::InternalServerError
    raise DeviceServiceError.new('STG Telematics: %s' % [I18n.t('errors.stg_telematics.unauthorized')])
  end

  def list_devices(customer)
    retry_counter = 0
    begin
      response = get_vehicles(customer.devices[:stg_telematics])
      body = JSON.parse(response.body)
      raise DeviceExpiredTokenError if !customer.devices[:stg_telematics].key?(:token) || body['result'] == 0 && body['message'].match(/Refresh Token Expired/)

      if response.code == 200 && data = body.dig('root', 'VehicleData')
        data.map do |item|
          { id: item['Vehicle_No'], text: [item['Vehicle_Name'], item['Vehicletype']].join(' ') }
        end
      else
        raise DeviceServiceError.new('STG Telematics: %s' % [I18n.t('errors.stg_telematics.list')])
      end
    rescue DeviceExpiredTokenError
      if retry_counter == 0
        update_access_token(customer)
        retry_counter += 1
        retry
      end
      raise DeviceServiceError.new('STG Telematics: %s' % [I18n.t('errors.stg_telematics.refresh_token_expired')])
    end
  rescue RestClient::RequestTimeout, Errno::ECONNREFUSED, SocketError
    raise DeviceServiceError.new('STG Telematics: %s' % [I18n.t('errors.stg_telematics.list')])
  end

  def get_vehicles_pos(customer)
    retry_counter = 0
    begin
      response = get_vehicles_position(customer.devices[:stg_telematics])
      body = JSON.parse(response.body)
      raise DeviceExpiredTokenError if !customer.devices[:stg_telematics].key?(:token) || body['result'] == 0 && body['message'].match(/Refresh Token Expired/)

      if response.code == 200 && body['data']
        body['data'].map do |item|
          {
            stg_telematics_vehicle_id: item['vehicleNumber'],
            device_name: item['vehicleNumber'],
            lat: item['lat'],
            lng: item['long'],
            speed: item['speed']&.delete(' kmph'),
            time: item['last_updated'] + '+00:00'
          }
        end
      else
        raise DeviceServiceError.new('STG Telematics: %s' % [I18n.t('errors.stg_telematics.get_vehicles_pos')])
      end
    rescue DeviceExpiredTokenError
      if retry_counter == 0
        update_access_token(customer)
        retry_counter += 1
        retry
      end
      raise DeviceServiceError.new('STG Telematics: %s' % [I18n.t('errors.stg_telematics.refresh_token_expired')])
    end
  end

  private

  def update_access_token(customer)
    response = get_access_token(customer.devices[:stg_telematics])
    if response.code == 200 && token = JSON.parse(response.body)&.dig('data', 'token')
      customer.devices[:stg_telematics][:token] = token if token
      customer.save!
    else
      raise DeviceServiceError.new('STG Telematics: %s' % [I18n.t('errors.stg_telematics.refresh_token_expired')])
    end
  end

  def get_access_token(params)
    rest_client_with_method(
      get_access_token_url(params),
      nil,
      { username: params[:username], password: params[:password] },
      :post
    )
  end

  def get_login_status(params)
    rest_client_with_method(
      get_login_status_url(params),
      params[:token],
      { username: params[:username], password: params[:password] },
      :post
    )
  end

  def get_vehicles(params)
    rest_client_with_method(
      get_vehicles_url(params),
      params[:token],
      { company_names: params[:company_names] },
      :get
    )
  end

  def get_vehicles_position(params)
    rest_client_with_method(
      get_vehicles_position_url(params),
      params[:token],
      nil,
      :post
    )
  end

  def get_access_token_url(_params)
    URI.encode("#{api_url}/webservice?token=generateAccessTokenDayWise")
  end

  def get_login_status_url(_params)
    URI.encode("#{api_url}/webservice?token=getLoginStatus")
  end

  def get_vehicles_url(_params)
    URI.encode("#{api_url}/webservice?token=getTokenBaseLiveData&ProjectId=37")
  end

  def get_vehicles_position_url(_params)
    URI.encode("#{api_url}/webservice?token=getVehicleLiveInformation")
  end

  def rest_client_with_method(url, token, params, method = :post)
    RestClient::Request.execute(
      method: method,
      url: url,
      headers: { content_type: :json, accept: :json, 'auth-code': token }.delete_if{ |_k, v| v.nil? },
      payload: params.to_json
    )
  rescue RestClient::RequestTimeout
    raise DeviceServiceError.new("#{I18n.t('errors.stg_telemativs.timeout')}")
  end
end
