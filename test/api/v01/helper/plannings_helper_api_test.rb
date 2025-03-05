require 'test_helper'

class PlanningsHelperApiTest < ActionController::TestCase
  include PlanningsHelperApi

  setup do
    @route = routes(:route_one_one)
    @planning = plannings(:planning_one)
    @customer = customers(:customer_one)
    @reseller = resellers(:reseller_one)
    @vehicle = vehicles(:vehicle_one)
    @vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
    @stop = stops(:stop_one_two)
    @destination = destinations(:destination_two)
    @visit = visits(:visit_two)
  end

  test 'should send sms for route' do
    messaging_service = mock('messaging_service')
    messaging_service.stubs(:service_name).returns('vonage')
    messaging_service.stubs(:content).returns('Message content')
    messaging_service.stubs(:send_message).returns(true)
    self.stubs(:get_messaging_service).returns(messaging_service)

    @route.stops.each{ |stop| stop&.visit&.destination&.update(phone_number: nil) }
    @destination.update!(phone_number: '+33600000000')
    @stop.update!(active: true)
    @route.reload

    assert_equal 1, send_sms_route(@route)
  end

  test 'should not send sms for route without phone number' do
    messaging_service = mock('messaging_service')
    messaging_service.stubs(:service_name).returns('vonage')
    messaging_service.stubs(:content).returns('Message content')
    self.stubs(:get_messaging_service).returns(messaging_service)

    @route.stops.each{ |stop| stop&.visit&.destination&.update(phone_number: nil) }
    @route.reload
    assert_equal 0, send_sms_route(@route)

    @destination.update!(phone_number: '')
    @route.reload
    assert_equal 0, send_sms_route(@route)
  end

  test 'should send sms for planning' do
    messaging_service = mock('messaging_service')
    messaging_service.stubs(:service_name).returns('vonage')
    messaging_service.stubs(:content).returns('Message content')
    messaging_service.stubs(:send_message).returns(true)
    self.stubs(:get_messaging_service).returns(messaging_service)

    @planning.routes.each{ |route| route.stops.each{ |stop| stop&.visit&.destination&.update(phone_number: nil)}}
    @destination.update!(phone_number: '+33600000000')
    @stop.update!(active: true)
    @planning.reload

    assert_equal 1, send_sms_planning(@planning)
  end

  test 'should send sms to drivers' do
    messaging_service = mock('messaging_service')
    messaging_service.stubs(:service_name).returns('vonage')
    messaging_service.stubs(:content).returns('Message content')
    messaging_service.stubs(:send_message).returns(true)
    self.stubs(:get_messaging_service).returns(messaging_service)

    @vehicle.update!(phone_number: '+33600000000')
    @route.update!(vehicle_usage: @vehicle_usage)
    @customer.update!(reseller: @reseller)

    phone_number_hash = { @route.id => '+33600000000' }
    assert_equal 1, send_sms_drivers([@route], phone_number_hash)
  end

  test 'should not send sms to drivers without phone number' do
    messaging_service = mock('messaging_service')
    messaging_service.stubs(:service_name).returns('vonage')
    self.stubs(:get_messaging_service).returns(messaging_service)

    @vehicle.update!(phone_number: nil)
    phone_number_hash = {}
    assert_equal 0, send_sms_drivers([@route], phone_number_hash)
  end

  test 'should get messaging service' do
    VonageService.stubs(:configured?).returns(true)
    assert_instance_of VonageService, get_messaging_service(@customer)

    VonageService.stubs(:configured?).returns(false)
    SmsPartnerService.stubs(:configured?).returns(true)
    assert_instance_of SmsPartnerService, get_messaging_service(@customer)

    SmsPartnerService.stubs(:configured?).returns(false)
    assert_raises(ArgumentError) { get_messaging_service(@customer) }
  end
end
