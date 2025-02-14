module MasternautBase

  def set_route
    @route = routes(:route_one_one)
    @route.update! end: @route.start + 5.hours
    @route.planning.update! date: 10.days.from_now
    @vehicle = @route.vehicle_usage.vehicle
    @vehicle.update! devices: {masternaut_ref: 'masternaut_ref'}
  end

  def add_masternaut_credentials customer
    customer.devices = {
      masternaut: {
        enable: 'true',
        username: 'masternaut_user',
        password: 'masternaut_password'
      }
    }
    customer.save!
    customer
  end

  def with_stubs names, &block
    begin
      stubs = []
      names.each do |name|
        api_url = URI.parse Planner::Application.config.devices.masternaut.api_url
        case name
          when :poi_wsdl
            expected_response = File.read(Rails.root.join("test/web_mocks/masternaut/POI.xml")).strip
            url = "%s://%s%s" % [ api_url.scheme, api_url.host, api_url.path + "/POI?wsdl" ]
            stubs << stub_request(:get, url).to_return(status: 200, body: expected_response)
          when :poi
            expected_response = File.read(Rails.root.join("test/web_mocks/masternaut/blank.xml")).strip
            url = "%s://%s%s" % [ api_url.scheme, api_url.host, api_url.path + "/POI" ]
            stubs << stub_request(:post, url).to_return(status: 200, body: expected_response)
          when :job_wsdl
            expected_response = File.read(Rails.root.join("test/web_mocks/masternaut/Job.xml")).strip
            url = "%s://%s%s" % [ api_url.scheme, api_url.host, api_url.path + "/Job?wsdl" ]
            stubs << stub_request(:get, url).to_return(status: 200, body: expected_response)
          when :job
            expected_response = File.read(Rails.root.join("test/web_mocks/masternaut/blank.xml")).strip
            url = "%s://%s%s" % [ api_url.scheme, api_url.host, api_url.path + "/Job" ]
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
