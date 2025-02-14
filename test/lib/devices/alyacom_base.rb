module AlyacomBase

  require 'erb'

  def set_route
    @route = routes(:route_one_one)
    @route.update! end: @route.start + 5.hours
    @route.planning.update! date: 10.days.from_now
  end

  def add_alyacom_credentials customer
    customer.devices = {
      alyacom: {
        enable: 'true',
        association: 'alyacom_association',
        api_key: '',
      }
    }
    customer.save!
    customer
  end

  def with_stubs values, &block
    begin
      stubs = []
      values.each do |method, names|
        case method
          when :get
            names.each do |name|
              case name
                when :staff, :users, :planning
                  expected_response = ERB.new(File.read(Rails.root.join("test/web_mocks/alyacom.fr/#{name}.json.erb"))).result(binding)
                  url = [URI.parse(Planner::Application.config.devices.alyacom.api_url), @customer.devices[:alyacom][:association], name.to_s].join "/"
                  stubs << stub_request(method, url).with(query: hash_including({ })).to_return(status: 200, body: expected_response)
              end
            end
          when :post
            names.each do |name|
              case name
                when :staff, :users, :planning
                  url = [URI.parse(Planner::Application.config.devices.alyacom.api_url), @customer.devices[:alyacom][:association], name.to_s].join "/"
                  stubs << stub_request(method, url).with(query: hash_including({ })).to_return(status: 200)
              end
            end
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
