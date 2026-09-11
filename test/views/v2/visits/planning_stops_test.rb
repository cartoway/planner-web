# frozen_string_literal: true

require 'test_helper'

class VisitPlanningStopsPartialTest < ActionView::TestCase
  include Rails.application.routes.url_helpers

  test 'lists plannings where the visit is a stop with a link to the planning' do
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select '.visit-planning-stops', 1
    assert_select '.visit-planning-stop', minimum: 1
    assert_includes rendered, plannings(:planning_one).name
    assert_select '.visit-planning-stop-color', text: stops(:stop_one_one).index.to_s
    refute_includes rendered, 'n°'
    stop = stops(:stop_one_one)
    assert_select %(a[href*="stop_id=#{stop.id}"][href*="route_id=#{stop.route_id}"][target="_blank"][rel="noopener noreferrer"])
  end

  test 'shows stop status as a colored badge' do
    stop = stops(:stop_one_one)
    stop.update_columns(status: 'delivered')
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select '.visit-planning-stop-status.badge.stop-status-delivered',
                  text: I18n.t('plannings.edit.stop_status.delivered')
  end

  test 'shows filled stop custom attributes' do
    stop = stops(:stop_one_one)
    stop.update_columns(custom_attributes: {
      'stop_custom_field' => 'signature ok',
      'stop_urgent' => false
    })
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select '.visit-planning-stop-attrs', 1
    assert_select '.visit-planning-stop-attr-name', text: 'stop_custom_field'
    assert_select '.visit-planning-stop-attr-value', text: 'signature ok'
    assert_select '.visit-planning-stop-attr-name', text: 'stop_urgent'
    assert_select '.visit-planning-stop-attr-value', text: I18n.t('all.value._no')
    refute_includes rendered, 'stop_priority'
    refute_includes rendered, 'default_stop_value'
  end

  test 'shows photos accordion on the matching stop' do
    stop = stops(:stop_one_one)
    stop.photos.attach(
      io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')),
      filename: 'stop_photo.jpg',
      content_type: 'image/jpeg'
    )
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select '.visit-planning-stop .visit-planning-photos-toggle', 1
    assert_select '.visit-planning-stop .visit-planning-photos .visit-planning-photo', 1
    assert_select '.visit-planning-stops > .visit-planning-photos-toggle', 0
  ensure
    stop&.photos&.purge
  end
end
