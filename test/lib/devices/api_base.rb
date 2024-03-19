module ApiBase

  def app
    Rails.application
  end

  def api(path, params = {})
    Addressable::Template.new("/api/0.1/#{path}.json{?query*}").expand(query: params.merge(api_key: 'testkey1')).to_s
  end

  def params_for(device, customer)
    device.to_sym unless device.is_a? Symbol
    case device
      when :fleet
        {
          user: customer.devices[device][:user],
          password: customer.devices[device][:password]
        }
      when :stg_telematics
        {
          url: customer.devices[device][:url],
          company_names: customer.devices[device][:company_names],
          username: customer.devices[device][:username],
          password: customer.devices[device][:password]
        }
      when :teksat
        {
          url: customer.devices[device][:url],
          teksat_customer_id: customer.devices[device][:teksat_customer_id],
          username: customer.devices[device][:username],
          password: customer.devices[device][:password]
        }
      when :tomtom
        {
          account: customer.devices[device][:account],
          user: customer.devices[device][:user],
          password: customer.devices[device][:password]
        }
      when :orange
        {
          user: customer.devices[device][:username],
          password: customer.devices[device][:password]
        }
      when :praxedo
        {
          login: customer.devices[device][:login],
          password: customer.devices[device][:password],
          code_inter_start: customer.devices[device][:code_inter_start],
          code_inter_stop: customer.devices[device][:code_inter_stop],
          code_mat: customer.devices[device][:code_mat],
          code_route: customer.devices[device][:code_route]
        }
      else
        raise 'Unknown Device params'
    end
  end
end
