module PraxedoBase

  def add_praxedo_credentials(customer)
    customer.devices = {
      praxedo: {
        enable: 'true',
        login: 'login',
        password: 'password',
        code_inter_start: 'START',
        code_inter_stop: 'STOP',
        code_mat: 'LIST_BAC'
      }
    }
    customer.enable_stop_status = true
    customer.save!
    customer
  end

  def set_route
    @route = routes(:route_one_one)
    @route.update!(end: @route.start + 5.hours)
    @route.planning.update!(date: 10.days.from_now)
    @vehicle = @route.vehicle_usage.vehicle
    @vehicle.update!(devices: { praxedo_agent_id: '91KVZ' })

    praxedo_tag = Tag.create(customer: @customer, label: 'praxedo:LIV')
    @route.stops.each_with_index do |stop, i|
      if stop.is_a?(StopVisit)
        stop.visit.ref = "1234#{i + 1}"
        stop.visit.tags << praxedo_tag
        stop.visit.save!
      end
    end
  end

  def with_stubs(names, &block)
    begin
      stubs = []
      names.each do |name|
        api_url = Planner::Application.config.devices.praxedo.api_url
        case name
          when :get_events_wsdl
            url = Addressable::Template.new "#{api_url}cxf/v6/BusinessEventManager?wsdl"
            stubs << stub_request(:get, url).to_return(File.read(Rails.root.join('test/web_mocks/praxedo/BusinessEventManager.wsdl.xml')))
          when :get_events
            url = Addressable::Template.new "#{api_url}cxf/v6/BusinessEventManager"
            stubs << stub_request(:post, url).to_return(File.read(Rails.root.join('test/web_mocks/praxedo/getEvents-checkAuth.xml')))
          when :create_events_wsdl
            url = Addressable::Template.new "#{api_url}cxf/v6/BusinessEventManager?wsdl"
            stubs << stub_request(:get, url).to_return(File.read(Rails.root.join('test/web_mocks/praxedo/BusinessEventManager.wsdl.xml')))
          when :create_events
            url = Addressable::Template.new "#{api_url}cxf/v6/BusinessEventManager"
            stubs << stub_request(:post, url).to_return(File.read(Rails.root.join('test/web_mocks/praxedo/createEvents-sendRoute.xml')))
          when :search_events_wsdl
            url = Addressable::Template.new "#{api_url}cxf/v6/BusinessEventManager?wsdl"
            stubs << stub_request(:get, url).to_return(File.read(Rails.root.join('test/web_mocks/praxedo/BusinessEventManager.wsdl.xml')))
          when :search_events
            url = Addressable::Template.new "#{api_url}cxf/v6/BusinessEventManager"
            stubs << stub_request(:post, url).with(body: /.*<firstResultIndex>0<\/firstResultIndex>.*/).to_return(File.read(Rails.root.join('test/web_mocks/praxedo/searchEvents-fetchStops.xml')))
            stubs << stub_request(:post, url).with(body: /.*<firstResultIndex>3<\/firstResultIndex>.*/).to_return(File.read(Rails.root.join('test/web_mocks/praxedo/searchEvents-fetchStops-empty.xml')))
          when :delete_events_wsdl
            url = Addressable::Template.new "#{api_url}cxf/v6/BusinessEventManager?wsdl"
            stubs << stub_request(:get, url).to_return(File.read(Rails.root.join('test/web_mocks/praxedo/BusinessEventManager.wsdl.xml')))
          when :delete_events
            url = Addressable::Template.new "#{api_url}cxf/v6/BusinessEventManager"
            stubs << stub_request(:post, url).to_return(File.read(Rails.root.join('test/web_mocks/praxedo/deleteEvents-clearRoute.xml')))
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
