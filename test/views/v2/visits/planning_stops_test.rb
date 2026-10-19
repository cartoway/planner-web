# frozen_string_literal: true

require 'test_helper'

class VisitPlanningStopsPartialTest < ActionView::TestCase
  include Rails.application.routes.url_helpers

  test 'lists plannings where the visit is a stop with a link to the planning' do
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select '.related-list', 1
    assert_select %(button.related-list-title[data-bs-toggle="collapse"][data-bs-target="#visit-#{visit.id}-planning-stops"][aria-expanded="true"]), 1
    assert_select 'button.related-list-title .fa-map-location.related-list-icon', 1
    assert_select 'button.related-list-title .accordion-chevron', 1
    assert_select %(.related-list-body.collapse.show#visit-#{visit.id}-planning-stops), 1
    assert_select '.related-item', minimum: 1
    assert_includes rendered, plannings(:planning_one).name
    assert_select '.related-item-index', text: stops(:stop_one_one).index.to_s
    refute_includes rendered, 'n°'
    stop = stops(:stop_one_one)
    assert_select %(a[href*="stop_id=#{stop.id}"][href*="route_id=#{stop.route_id}"][target="_blank"][rel="noopener noreferrer"])
  end

  test 'does not show stop custom attributes' do
    stop = stops(:stop_one_one)
    stop.update_columns(custom_attributes: {
      'stop_custom_field' => 'signature ok',
      'stop_urgent' => false
    })
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    refute_includes rendered, 'signature ok'
    refute_includes rendered, 'stop_custom_field'
    refute_includes rendered, 'stop_urgent'
    assert_select '.related-item-attrs', 0
  end

  test 'does not show delivery note or stop attachments (owned by operations)' do
    stop = stops(:stop_one_one)
    stop.update_columns(status: 'delivered')
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select '.related-item-docs', 0
    assert_select '.related-item-photos-toggle', 0
  end

  test 'shows stop status as a colored badge' do
    stop = stops(:stop_one_one)
    stop.update_columns(status: 'delivered')
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select '.related-item-status.badge.stop-status-delivered',
                  text: I18n.t('plannings.edit.stop_status.delivered')
  end
end
