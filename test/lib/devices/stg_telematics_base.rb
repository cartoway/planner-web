module StgTelematicsBase

  def set_route
    @route = routes(:route_one_one)
    @route.update! end: @route.start + 5.hours
    @route.planning.update! date: 10.days.from_now
    @vehicle = @route.vehicle_usage.vehicle
    @vehicle.update! devices: {stg_telematics_vehicle_id: '12345-V-6'}
  end

  def add_stg_telematics_credentials(customer)
    customer.devices = {
      stg_telematics: {
        enable: 'true',
        company_names: 'foo',
        url: 'api.stgtelematics.com',
        username: 'bar',
        password: 'pass'
      }
    }
    customer.save!
    customer
  end

  def with_stubs names, &block
    begin
      stubs = []
      names.each do |name|
        case name
          when :auth
            params = {
              url: @customer.devices[:stg_telematics][:url],
              company_names: @customer.devices[:stg_telematics][:company_names],
              username: @customer.devices[:stg_telematics][:username],
              password: @customer.devices[:stg_telematics][:password]
            }
            expected_response = File.read(Rails.root.join("test/web_mocks/stg_telematics/generateAccessTokenDayWise.json")).strip
            url = StgTelematicsService.new(customer: @customer).service.send :get_access_token_url, params
            stubs << stub_request(:post, url).to_return(status: 200, body: expected_response)
          when :get_vehicles
            params = { company_names: @customer.devices[:stg_telematics][:company_names], url: @customer.devices[:stg_telematics][:url] }
            expected_response = File.read(Rails.root.join("test/web_mocks/stg_telematics/getTokenBaseLiveData.json")).strip
            url = StgTelematicsService.new(customer: @customer).service.send :get_vehicles_url, params
            stubs << stub_request(:get, url).to_return(status: 200, body: expected_response)
          when :vehicles_pos
            params = { url: @customer.devices[:stg_telematics][:url]}
            expected_response = File.read(Rails.root.join("test/web_mocks/stg_telematics/getVehicleLiveInformation.json")).strip
            url = StgTelematicsService.new(customer: @customer).service.send :get_vehicles_position_url, params
            stubs << stub_request(:post, url).to_return(status: 200, body: expected_response)
        end
      end
      yield
    ensure
      stubs.each do |name|
        remove_request_stub name
      end
    end
  end
end
