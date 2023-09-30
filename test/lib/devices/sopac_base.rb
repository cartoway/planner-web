module SopacBase

  def add_sopac_credentials customer
    customer.devices = {
      sopac: {
        enable: 'true',
        username: 'sebastien.rigolat@example.com',
        password: '2018'
      }
    }
    customer.save!
    customer.vehicles.first.update! devices: {sopac_id: '2000352F'}
    customer
  end

  def with_stubs(names, &block)
    begin
      stubs = []
      names.each do |name|
        case name
          when :list_devices
            expected = File.read(Rails.root.join('test/web_mocks/sopac/devices_list.xml'))
            url = 'https://restservice1.bluconsole.com/bluconsolerest/1.0/resources/devices?uname&upass=2018'
            stubs << stub_request(:get, url).to_return(status: 200, body: expected)
          when :single_device
            expected = File.read(Rails.root.join('test/web_mocks/sopac/single_device.xml'))
            url = 'https://restservice1.bluconsole.com/bluconsolerest/1.0/resources/devices?id=2000352F&uname=sebastien.rigolat@example.com&upass=2018'
            stubs << stub_request(:get, url).to_return(status: 200, body: expected)
          when :auth
            url = 'https://restservice1.bluconsole.com/bluconsolerest/1.0/resources/devices?uname&upass='
            expected = File.read(Rails.root.join('test/web_mocks/sopac/bad_auth.xml'))
            stubs << stub_request(:get, url).to_return(status: 200, body: expected, headers: {})
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
