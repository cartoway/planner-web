# frozen_string_literal: true

require 'test_helper'

class VisitPlanningStopsPartialTest < ActionView::TestCase
  include Rails.application.routes.url_helpers

  test 'lists plannings where the visit is a stop with a link to the planning' do
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select '.related-list', 1
    assert_select '.related-item', minimum: 1
    assert_includes rendered, plannings(:planning_one).name
    assert_select '.related-item-index', text: stops(:stop_one_one).index.to_s
    refute_includes rendered, 'n°'
    stop = stops(:stop_one_one)
    assert_select %(a[href*="stop_id=#{stop.id}"][href*="route_id=#{stop.route_id}"][target="_blank"][rel="noopener noreferrer"])
    assert_select %(a[href="#{delivery_note_stop_path(stop)}"]), 0
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

  test 'shows delivery note link when stop is delivered' do
    stop = stops(:stop_one_one)
    stop.update_columns(status: 'delivered')
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select %(a[href="#{delivery_note_stop_path(stop)}"][target="_blank"][rel="noopener noreferrer"])
  end

  test 'shows stop status as a colored badge' do
    stop = stops(:stop_one_one)
    stop.update_columns(status: 'delivered')
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    assert_select '.related-item-status.badge.stop-status-delivered',
                  text: I18n.t('plannings.edit.stop_status.delivered')
  end

  test 'shows photos accordion on the matching stop' do
    stop = stops(:stop_one_one)
    stop.photos.purge if stop.photos.attached?
    stop.signature.purge if stop.signature.attached?
    stop.photos.attach(
      io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')),
      filename: 'stop_photo.jpg',
      content_type: 'image/jpeg'
    )
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    photos_id = "visit-#{visit.id}-stop-#{stop.id}-photos"
    assert_select '.related-item .related-item-photos-toggle', 1
    assert_select %(.related-item-photos##{photos_id} .related-item-photo), 1
    assert_select '.related-list > .related-item-photos-toggle', 0
  ensure
    stop&.photos&.purge
    stop&.signature&.purge if stop&.signature&.attached?
  end

  test 'photos and signature collapses share a parent accordion' do
    stop = stops(:stop_one_one)
    stop.photos.purge if stop.photos.attached?
    stop.signature.purge if stop.signature.attached?
    stop.photos.attach(
      io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')),
      filename: 'stop_photo.jpg',
      content_type: 'image/jpeg'
    )
    stop.attach_signature(
      Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/stop_photo.jpg'), 'image/jpeg')
    )
    visit = visits(:visit_one)
    render partial: 'v2/visits/planning_stops', locals: { visit: visit }

    docs_id = "visit-#{visit.id}-stop-#{stop.id}-docs"
    assert_select %(.related-item-docs[id="#{docs_id}"]), 1
    assert_select '.related-item-docs-toggles .related-item-photos-toggle', 2
    assert_select %(.related-item-photos[data-bs-parent="##{docs_id}"]), 2
  ensure
    stop&.photos&.purge
    stop&.signature&.purge if stop&.signature&.attached?
  end
end
