require 'test_helper'

class NoticoTest < ActionController::TestCase

  require Rails.root.join('test/lib/devices/notico_base')
  include NoticoBase

  setup do
    @customer = add_notico_credentials(customers(:customer_one))
    @service = Planner::Application.config.devices.notico
  end

  def around
    Planner::Application.config.devices.notico.class.stub_any_instance(:get, lambda { |_credentials, _options = {}| true }) do
      yield
    end
  end

  test 'check authentication' do
    params = {
        user: @customer.devices[:notico][:username],
        password: @customer.devices[:notico][:password]
    }
    assert @service.check_auth(params)
  end

  test 'send route' do
    set_route

    assert_nothing_raised do
      assert @service.send_route(@customer, @route)
    end
  end

  test 'clear route' do
    set_route
    assert_nothing_raised do
      @service.clear_route(@customer, @route)
    end
  end
end
