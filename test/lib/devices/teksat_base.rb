module TeksatBase

  def set_route
    @route = routes(:route_one_one)
    @route.update! end: @route.start + 5.hours
    @route.planning.update! date: 10.days.from_now
    @vehicle = @route.vehicle_usage.vehicle
    @vehicle.update! devices: {teksat_id: '1091'}
  end

  def add_teksat_credentials(customer)

    customer.devices = {
      teksat: {
        enable: 'true',
        teksat_customer_id: rand(100).to_s,
        username: 'teksat_username',
        password: 'teksat_password',
        url: 'www.gps00.teksat.fr'
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
            @ticket_id = File.read(Rails.root.join("test/web_mocks/teksat/get_ticket")).strip
            params = {
              url: @customer.devices[:teksat][:url],
              teksat_customer_id: @customer.devices[:teksat][:teksat_customer_id],
              username: @customer.devices[:teksat][:username],
              password: @customer.devices[:teksat][:password]
            }
            url = TeksatService.new(customer: @customer).service.send :get_ticket_url, @customer, params
            stubs << stub_request(:get, url).to_return(status: 200, body: @ticket_id)
          when :get_vehicles
            expected_response = File.read(Rails.root.join("test/web_mocks/teksat/get_vehicles.xml")).strip
            url = TeksatService.new(customer: @customer, ticket_id: @ticket_id).service.send :get_vehicles_url, @customer
            stubs << stub_request(:get, url).to_return(status: 200, body: expected_response)
          when :vehicles_pos
            expected_response = File.read(Rails.root.join("test/web_mocks/teksat/get_vehicles_pos.xml")).strip
            url = TeksatService.new(customer: @customer, ticket_id: @ticket_id).service.send :vehicle_pos_url, @customer
            stubs << stub_request(:get, url).to_return(status: 200, body: expected_response)
          when :send_route
            expected_response = File.read(Rails.root.join("test/web_mocks/teksat/mission_data.xml")).strip
            url = @customer.devices[:teksat][:url] + "/webservices/map/set-mission.jsp"
            stubs << stub_request(:get, url).with(:query => hash_including({ })).to_return(status: 200, body: expected_response)
          when :clear_route
            expected_response = File.read(Rails.root.join("test/web_mocks/teksat/get_missions.xml")).strip
            url = @customer.devices[:teksat][:url] + "/webservices/map/get-missions.jsp"
            stubs << stub_request(:get, url).with(:query => hash_including({ })).to_return(status: 200, body: expected_response)
            expected_response = File.read(Rails.root.join("test/web_mocks/teksat/mission_data.xml")).strip
            url = @customer.devices[:teksat][:url] + "/webservices/map/delete-mission.jsp"
            stubs << stub_request(:get, url).with(:query => hash_including({ })).to_return(status: 200, body: expected_response)
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
