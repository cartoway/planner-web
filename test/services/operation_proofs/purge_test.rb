# frozen_string_literal: true

require 'test_helper'

class OperationProofsPurgeTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    @customer.update!(proof_retention_days: 365)
    @planning.update!(date: Date.new(2024, 1, 1))
    @operation = Operations::PublishFromPlanning.call(planning: @planning, date: '2024-01-01')
    @stop = @operation.operation_stops.find { |row| row.kind == 'visit' }
    file = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/stop_photo.jpg'), 'image/jpeg')
    assert @stop.attach_photos([file])
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'purge removes proofs for operations older than retention' do
    assert @stop.photos.attached?

    deleted = OperationProofs::Purge.call
    assert_operator deleted, :>=, 1
    @stop.reload
    refute @stop.photos.attached?
  end

  test 'purge keeps proofs within retention window' do
    @customer.update!(proof_retention_days: 1825)
    assert @stop.photos.attached?

    deleted = OperationProofs::Purge.call
    assert_equal 0, deleted
    assert @stop.reload.photos.attached?
  end
end
