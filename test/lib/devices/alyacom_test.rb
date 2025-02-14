require 'test_helper'

class AlyacomTest < ActionController::TestCase

  require Rails.root.join("test/lib/devices/alyacom_base")
  include AlyacomBase

  setup do
    @customer = add_alyacom_credentials customers(:customer_one)
    @service = Planner::Application.config.devices.alyacom
  end

  test 'send route' do
    with_stubs({ get: [:staff, :users, :planning], post: [:staff, :users, :planning] }) do
      set_route
      assert_nothing_raised do
        @service.send_route @customer, @route
      end
    end
  end

end
