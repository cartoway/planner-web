# frozen_string_literal: true

require 'test_helper'

class OperationStopRowPartialTest < ActionView::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    Operation.where(customer_id: @customer.id).delete_all
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @stop = OperationStop.where(visit_id: visits(:visit_one).id).first
    assert @stop
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'renders operation stop like planning stop rows with icon link' do
    render partial: 'v2/operation_stops/row', locals: { stop: @stop, docs_prefix: "op-stop-#{@stop.id}" }

    assert_select '.related-item', 1
    assert_select '.related-item-name', text: /#{Regexp.escape(@operation.name)}/
    assert_select '.related-item-index', text: @stop.index.to_s
    assert_select %(a.btn.btn-light[href="#{operation_path(@operation, anchor: "stop-#{@stop.id}")}"][target="_blank"][rel="noopener noreferrer"]) do
      assert_select 'i.fa-clipboard-check'
    end
  end

  test 'shows status badge when status present' do
    @stop.update_columns(status: 'delivered')
    render partial: 'v2/operation_stops/row', locals: { stop: @stop, docs_prefix: "op-stop-#{@stop.id}" }

    assert_select '.related-item-status.badge.stop-status-delivered',
                  text: I18n.t('plannings.edit.stop_status.delivered')
  end
end
