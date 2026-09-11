require 'test_helper'

class StopPhotosControllerTest < ActionController::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    customers(:customer_one).update(job_optimizer_id: nil)
    request.host = resellers(:reseller_one).host
    @stop = stops(:stop_one_one)
    @vehicle = vehicles(:vehicle_one)
  end

  teardown do
    @stop&.photos&.purge
  end

  test 'driver can upload a photo and fetch it via signed url' do
    assert_difference -> { @stop.photos.count }, 1 do
      post :create, params: {
        stop_id: @stop.id,
        driver_token: @vehicle.driver_token,
        photos: [fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')]
      }, format: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal 1, body['photos'].size
    photo = body['photos'].first
    assert photo['url'].present?
    assert_equal 'stop_photo.jpg', photo['filename']
    assert_equal true, photo['deletable']

    signed_id = Stop.photo_verifier.generate(@stop.photos.first.blob.id, expires_in: Stop::PHOTO_URL_EXPIRES_IN, purpose: Stop::PHOTO_SIGNED_ID_PURPOSE)
    get :show, params: { signed_id: signed_id }
    assert_response :success
    assert_equal 'image/jpeg', response.media_type

    delete :destroy, params: {
      stop_id: @stop.id,
      id: photo['id'],
      driver_token: @vehicle.driver_token
    }, format: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)['photos']
  end

  test 'driver cannot delete a photo after one hour' do
    post :create, params: {
      stop_id: @stop.id,
      driver_token: @vehicle.driver_token,
      photos: [fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')]
    }, format: :json
    photo_id = JSON.parse(response.body)['photos'].first['id']

    travel Stop::PHOTO_DELETABLE_FOR + 1.second do
      delete :destroy, params: {
        stop_id: @stop.id,
        id: photo_id,
        driver_token: @vehicle.driver_token
      }, format: :json
    end

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal I18n.t('stops.mobile.photos_delete_expired'), body['error']
    assert_equal 1, body['photos'].size
    assert_equal false, body['photos'].first['deletable']
    assert @stop.reload.photos.attached?
  end

  test 'expired signed id returns not found' do
    @stop.photos.attach(io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')), filename: 'stop_photo.jpg', content_type: 'image/jpeg')
    signed_id = Stop.photo_verifier.generate(@stop.photos.first.blob.id, expires_in: 15.minutes, purpose: Stop::PHOTO_SIGNED_ID_PURPOSE)

    travel 16.minutes do
      get :show, params: { signed_id: signed_id }
      assert_response :not_found
    end
  end

  test 'bogus signed id returns not found' do
    get :show, params: { signed_id: 'not-a-valid-signed-id' }
    assert_response :not_found
  end

  test 'other vehicle cannot upload photos on this stop' do
    post :create, params: {
      stop_id: @stop.id,
      driver_token: vehicles(:vehicle_three).driver_token,
      photos: [fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')]
    }, format: :json

    assert_response :not_found
    assert_not @stop.reload.photos.attached?
  end
end
