require 'test_helper'

class RouteMobileTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include Rails.application.routes.url_helpers
  include ActiveSupport::Testing::TimeHelpers

  def app
    Rails.application
  end
  setup do
    @route = routes(:route_one_one)
    @route.planning.update!(date: 1.week.from_now.to_date)
  end

  test 'should redirect to sign in page if key is invalid' do
    get "routes/#{@route.id}/mobile/?driver_token=bad_key"

    assert last_response.status, 302
    assert_match(/text\/html/, last_response.content_type)
    assert_match(/#{new_user_session_path}/, last_response.location)
  end

  test 'should display the requested page if key is valid' do
    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.status, 200
  end

  test 'should always show stop visit custom attributes on mobile' do
    visible_attr = custom_attributes(:custom_attribute_stop_one)
    hidden_on_mobile_attr = custom_attributes(:custom_attribute_stop_two)

    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_includes last_response.body, visible_attr.name
    assert_includes last_response.body, hidden_on_mobile_attr.name
  end

  test 'should show vehicle and route custom attributes visible on mobile' do
    vehicle = @route.vehicle_usage.vehicle
    vehicle.update!(custom_attributes: {
      'custom_attribute_one' => 42,
      'vehicle_info_hidden' => 'secret vehicle info'
    })
    @route.reload.update!(custom_attributes: {
      'route_info_visible' => 'shown route info',
      'route_info_hidden' => 'secret route info'
    })

    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_includes last_response.body, 'custom_attribute_one'
    assert_includes last_response.body, '42'
    assert_includes last_response.body, 'route_info_visible'
    assert_includes last_response.body, 'shown route info'
    refute_includes last_response.body, 'vehicle_info_hidden'
    refute_includes last_response.body, 'secret vehicle info'
    refute_includes last_response.body, 'route_info_hidden'
    refute_includes last_response.body, 'secret route info'
  end

  test 'should hide visit custom attributes not visible on mobile' do
    visit = visits(:visit_one)
    visit.update!(custom_attributes: {
      'visit_info_visible' => 'shown value',
      'visit_info_hidden' => 'secret value'
    })

    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_includes last_response.body, 'visit_info_visible'
    assert_includes last_response.body, 'shown value'
    refute_includes last_response.body, 'visit_info_hidden'
    refute_includes last_response.body, 'secret value'
  end

  test 'should show photo capture and gallery buttons for each stop' do
    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_includes last_response.body, 'stop-photos-pick'
    assert_match(/<label[^>]*stop-photos-pick[\s\S]*?stop-photos-camera-input/m, last_response.body)
    assert_includes last_response.body, 'stop-photos-gallery-input'
    assert_match(/capture=["']environment["']/, last_response.body)
    assert_includes last_response.body, 'stop-photos-accordion d-none'
    refute_match(/stop-photos-toggle[^>]*data-toggle/, last_response.body)
    refute_match(/stop-photos-toggle[^>]*no-toggle/, last_response.body)
    refute_includes last_response.body, 'stop-photo-remove'
    assert_includes last_response.body, I18n.t('stops.mobile.take_photo')
    assert_includes last_response.body, 'stop-photo-modal'
    assert_includes last_response.body, 'stop-photo-modal-prev'
    assert_includes last_response.body, 'stop-photo-modal-next'
    assert_includes last_response.body, 'stop-photo-modal-delete'
    assert_match(/stop-photo-modal-delete[^>]*btn-xs/, last_response.body)
    assert_match(/stop-photo-modal-close[^>]*btn-xs/, last_response.body)
  end

  test 'should list loaded photos with a delete button' do
    stop = @route.stops.find { |s| s.is_a?(StopVisit) }
    stop.photos.attach(
      io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')),
      filename: 'stop_photo.jpg',
      content_type: 'image/jpeg'
    )

    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_includes last_response.body, 'stop-photo-remove'
    assert_match(/stop-photo-remove[^>]*>\s*<i class=['"]fa fa-trash/, last_response.body)
    assert_includes last_response.body, 'stop-photo-modal-delete'
    assert_includes last_response.body, 'stop-photo-open'
    assert_includes last_response.body, 'stop-photo-modal'
    refute_match(/stop-photo-open[\s\S]*target="_blank"/, last_response.body)
    assert_includes last_response.body, "photos-panel-#{stop.id}"
    assert_includes last_response.body, stop_photo_path(stop, stop.photos.first.id)
  ensure
    stop&.photos&.purge
  end

  test 'should hide photo delete button after one hour' do
    stop = @route.stops.find { |s| s.is_a?(StopVisit) }
    stop.photos.attach(
      io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')),
      filename: 'stop_photo.jpg',
      content_type: 'image/jpeg'
    )

    vehicle = @route.vehicle_usage.vehicle
    travel Stop::PHOTO_DELETABLE_FOR + 1.second do
      get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"
    end

    assert last_response.ok?
    refute_includes last_response.body, 'stop-photo-remove'
  ensure
    stop&.photos&.purge
  end

  test 'should preserve multiline destination comment on mobile' do
    destination = destinations(:destination_one)
    destination.update!(comment: "Line 1\nLine 2")

    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_match(/wrapped-text/, last_response.body)
    assert_includes last_response.body, 'Line 1'
    assert_includes last_response.body, 'Line 2'
  end
end
