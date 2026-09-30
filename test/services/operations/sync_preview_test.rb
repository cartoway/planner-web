# frozen_string_literal: true

require 'test_helper'

class OperationsSyncPreviewTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'fresh publish has no dirty routes' do
    preview = Operations::SyncPreview.call(planning: @planning, operation: @operation)
    assert preview.values.all? { |change| change['in_operation'] && !change['dirty'] }
  end

  test 'marks a route dirty when a planning stop disappears' do
    operation_stop = @operation.operation_stops.find_by!(visit_id: visits(:visit_one).id)
    route_id = operation_stop.operation_route.route_id
    Stop.where(id: operation_stop.stop_id).delete_all

    preview = Operations::SyncPreview.call(planning: @planning.reload, operation: @operation)
    change = preview[route_id.to_s]
    assert change['in_operation']
    assert change['dirty']
    assert_operator change['removed'], :>=, 1
  end
end
