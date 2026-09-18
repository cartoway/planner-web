require 'test_helper'

class StopSignaturesControllerTest < ActionController::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    customers(:customer_one).update(job_optimizer_id: nil)
    request.host = resellers(:reseller_one).host
    @stop = stops(:stop_one_one)
    @vehicle = vehicles(:vehicle_one)
  end

  teardown do
    @stop&.signature&.purge if @stop&.signature&.attached?
  end

  test 'driver can upload a signature and fetch it via signed url' do
    assert_difference -> { ActiveStorage::Attachment.where(name: 'signature', record: @stop).count }, 1 do
      post :create, params: {
        stop_id: @stop.id,
        driver_token: @vehicle.driver_token,
        signature: fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')
      }, format: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body['signature'].present?
    assert_equal 'stop_photo.jpg', body['signature']['filename']
    assert_nil body['signature']['deletable']
    assert body['signature']['url'].present?

    signed_id = Stop.signature_verifier.generate(
      @stop.signature.blob.id,
      expires_in: Stop::SIGNATURE_URL_EXPIRES_IN,
      purpose: Stop::SIGNATURE_SIGNED_ID_PURPOSE
    )
    get :show, params: { signed_id: signed_id }
    assert_response :success
    assert_equal 'image/jpeg', response.media_type
  end

  test 'driver can replace a signature after any delay' do
    post :create, params: {
      stop_id: @stop.id,
      driver_token: @vehicle.driver_token,
      signature: fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')
    }, format: :json
    assert_response :created
    first_blob_id = @stop.reload.signature.blob.id

    travel 2.hours do
      post :create, params: {
        stop_id: @stop.id,
        driver_token: @vehicle.driver_token,
        signature: fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')
      }, format: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body['signature'].present?
    assert @stop.reload.signature.attached?
    assert_not_equal first_blob_id, @stop.signature.blob.id
  end

  test 'other vehicle cannot upload signature on this stop' do
    other = vehicles(:vehicle_three)
    post :create, params: {
      stop_id: @stop.id,
      driver_token: other.driver_token,
      signature: fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')
    }, format: :json
    assert_response :not_found
    assert_not @stop.reload.signature.attached?
  end
end
