require 'test_helper'

class StopPhotosControllerTest < ActionController::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    customers(:customer_one).update(job_optimizer_id: nil)
    request.host = resellers(:reseller_one).host
    @planning = plannings(:planning_one)
    Operation.where(customer_id: @planning.customer_id).delete_all
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @operation_stop = @operation.operation_stops.find_by!(stop_id: stops(:stop_one_one).id)
    @vehicle = vehicles(:vehicle_one)
  end

  teardown do
    @operation_stop&.photos&.purge
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'driver can upload a photo and fetch it via signed url' do
    assert_difference -> { @operation_stop.photos.count }, 1 do
      post :create, params: {
        operation_stop_id: @operation_stop.id,
        driver_token: @vehicle.driver_token,
        photos: [fixture_file_upload('stop_photo.jpg', 'image/jpeg')]
      }, format: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal 1, body['photos'].size
    photo = body['photos'].first
    assert photo['url'].present?
    assert_equal 'stop_photo.jpg', photo['filename']
    assert_equal true, photo['deletable']

    signed_id = OperationStop.photo_verifier.generate(
      @operation_stop.photos.first.blob.id,
      expires_in: ProofAttachments::PHOTO_URL_EXPIRES_IN,
      purpose: ProofAttachments::PHOTO_SIGNED_ID_PURPOSE
    )
    get :show, params: { signed_id: signed_id }
    assert_response :success
    assert_equal 'image/jpeg', response.media_type

    delete :destroy, params: {
      operation_stop_id: @operation_stop.id,
      id: photo['id'],
      driver_token: @vehicle.driver_token
    }, format: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)['photos']
  end

  test 'driver cannot delete a photo after one hour' do
    post :create, params: {
      operation_stop_id: @operation_stop.id,
      driver_token: @vehicle.driver_token,
      photos: [fixture_file_upload('stop_photo.jpg', 'image/jpeg')]
    }, format: :json
    photo_id = JSON.parse(response.body)['photos'].first['id']

    travel ProofAttachments::PHOTO_DELETABLE_FOR + 1.second do
      delete :destroy, params: {
        operation_stop_id: @operation_stop.id,
        id: photo_id,
        driver_token: @vehicle.driver_token
      }, format: :json
    end

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal I18n.t('stops.mobile.photos_delete_expired'), body['error']
    assert_equal 1, body['photos'].size
    assert_equal false, body['photos'].first['deletable']
    assert @operation_stop.reload.photos.attached?
  end

  test 'expired signed id returns not found' do
    @operation_stop.photos.attach(io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')), filename: 'stop_photo.jpg', content_type: 'image/jpeg')
    signed_id = OperationStop.photo_verifier.generate(
      @operation_stop.photos.first.blob.id,
      expires_in: 15.minutes,
      purpose: ProofAttachments::PHOTO_SIGNED_ID_PURPOSE
    )

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
      operation_stop_id: @operation_stop.id,
      driver_token: vehicles(:vehicle_three).driver_token,
      photos: [fixture_file_upload('stop_photo.jpg', 'image/jpeg')]
    }, format: :json

    assert_response :not_found
    assert_not @operation_stop.reload.photos.attached?
  end

  test 'too many photos returns translated 422 instead of missing translation' do
    I18n.with_locale(:fr) do
      ProofAttachments::PHOTO_MAX_COUNT.times do
        post :create, params: {
          operation_stop_id: @operation_stop.id,
          driver_token: @vehicle.driver_token,
          photos: [fixture_file_upload('stop_photo.jpg', 'image/jpeg')]
        }, format: :json
        assert_response :created
      end

      post :create, params: {
        operation_stop_id: @operation_stop.id,
        driver_token: @vehicle.driver_token,
        photos: [fixture_file_upload('stop_photo.jpg', 'image/jpeg')]
      }, format: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_match(/#{ProofAttachments::PHOTO_MAX_COUNT}/, body['error'])
    assert_no_match(/Translation missing/i, body['error'])
    assert_kind_of Array, body['errors']
    assert_predicate body['errors'], :present?
  end
end
