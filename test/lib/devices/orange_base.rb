module OrangeBase

  def set_route
    @route = routes(:route_one_one)
    @route.update! end: @route.start + 5.hours
    @route.planning.update! date: 10.days.from_now
    @vehicle = @route.vehicle_usage.vehicle
    @vehicle.update! devices: {orange_id: '325000749'}
  end

  def add_orange_credentials customer
    customer.devices = {
      orange: {
        enable: 'true',
        username: 'orange_user',
        password: 'orange_password',
      }
    }
    customer.save!
    customer
  end

  def with_stubs names, &block
    begin
      stubs = []
      names.each do |name|
        api_url = URI.parse Planner::Application.config.devices.orange.api_url
        case name
          when :auth
            expected_response = File.read(Rails.root.join("test/web_mocks/orange/blank.xml")).strip
            url = "%s://%s%s" % [ api_url.scheme, api_url.host, "/pnd/index.php" ]
            stubs << stub_request(:get, url).with(query: hash_including({ })).to_return(status: 200, body: expected_response)
          when :send
            expected_response = File.read(Rails.root.join("test/web_mocks/orange/blank.xml")).strip
            url = "%s://%s%s" % [ api_url.scheme, api_url.host, "/pnd/index.php" ]
            stubs << stub_request(:post, url).with(query: hash_including({ })).to_return(status: 200, body: expected_response)
          when :get_vehicles
            expected_response = File.read(Rails.root.join("test/web_mocks/orange/get_vehicles.xml")).strip
            url = "%s://%s%s" % [ api_url.scheme, api_url.host, "/webservices/getvehicles.php" ]
            stubs << stub_request(:get, url).with(body: { ext: "xml" }).to_return(status: 200, body: expected_response)
          when :vehicles_pos
            expected_response = File.read(Rails.root.join("test/web_mocks/orange/get_vehicles_pos.xml")).strip
            url = "%s://%s%s" % [ api_url.scheme, api_url.host, "/webservices/getpositions.php" ]
            stubs << stub_request(:get, url).with(body: { ext: "xml" }).to_return(status: 200, body: expected_response)
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
