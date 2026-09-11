require 'test_helper'

class VehiclesHelperTest < ActionView::TestCase
  test 'customer_router_boolean_default_label handles boolean and string router option values' do
    customer = customers(:customer_one)
    customer.update!(router_options: customer.router_options.merge('traffic' => 'true', 'motorway' => false))

    assert_equal t('customers.form.router_options_traffic_yes'), customer_router_boolean_default_label(customer, :traffic)
    assert_equal t('customers.form.router_options_motorway_no'), customer_router_boolean_default_label(customer, :motorway)
  end
end
