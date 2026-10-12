require 'test_helper'

class StopSignaturesControllerTest < ActionController::TestCase
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
    @operation_stop&.signature&.purge if @operation_stop&.signature&.attached?
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'driver can upload a signature and fetch it via signed url' do
    assert_difference -> { ActiveStorage::Attachment.where(name: 'signature', record: @operation_stop).count }, 1 do
      post :create, params: {
        operation_stop_id: @operation_stop.id,
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

    signed_id = OperationStop.signature_verifier.generate(
      @operation_stop.signature.blob.id,
      expires_in: ProofAttachments::SIGNATURE_URL_EXPIRES_IN,
      purpose: ProofAttachments::SIGNATURE_SIGNED_ID_PURPOSE
    )
    get :show, params: { signed_id: signed_id }
    assert_response :success
    assert_equal 'image/jpeg', response.media_type
  end

  test 'driver can replace a signature after any delay' do
    post :create, params: {
      operation_stop_id: @operation_stop.id,
      driver_token: @vehicle.driver_token,
      signature: fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')
    }, format: :json
    assert_response :created
    first_blob_id = @operation_stop.reload.signature.blob.id

    travel 2.hours do
      post :create, params: {
        operation_stop_id: @operation_stop.id,
        driver_token: @vehicle.driver_token,
        signature: fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')
      }, format: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body['signature'].present?
    assert @operation_stop.reload.signature.attached?
    assert_not_equal first_blob_id, @operation_stop.signature.blob.id
  end

  test 'other vehicle cannot upload signature on this stop' do
    other = vehicles(:vehicle_three)
    post :create, params: {
      operation_stop_id: @operation_stop.id,
      driver_token: other.driver_token,
      signature: fixture_file_upload('files/stop_photo.jpg', 'image/jpeg')
    }, format: :json
    assert_response :not_found
    assert_not @operation_stop.reload.signature.attached?
  end
end
