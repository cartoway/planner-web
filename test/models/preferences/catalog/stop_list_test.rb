# frozen_string_literal: true

require 'test_helper'

class Preferences::Catalog::StopListTest < ActiveSupport::TestCase
  test 'normalize_zone caps active at three and keeps order' do
    z = {
      'active' => %w[name ref street],
      'hidden' => ['status']
    }
    out = Preferences::Catalog::StopList.normalize_zone(z)
    assert_equal %w[name ref street], out['active']
    assert_includes out['hidden'], 'eta'
    assert_includes out['hidden'], 'status'
  end

  test 'normalize_zone defaults when empty active' do
    out = Preferences::Catalog::StopList.normalize_zone(
      'active' => [],
      'hidden' => Preferences::Catalog::StopList::FIELD_IDS
    )
    assert_equal Preferences::Catalog::StopList::DEFAULT_ACTIVE, out['active']
  end

  test 'field_value maps stop hash keys' do
    stop = { name: 'A', ref: 'R1', eta_formated: '10:00', status: 'ok' }
    assert_equal 'A', Preferences::Catalog::StopList.field_value(stop, 'name')
    assert_equal 'R1', Preferences::Catalog::StopList.field_value(stop, 'ref')
    assert_equal '10:00', Preferences::Catalog::StopList.field_value(stop, 'eta')
    assert_equal 'ok', Preferences::Catalog::StopList.field_value(stop, 'status')
  end

  test 'field_value maps visit and destination fields from JSON-shaped hash' do
    stop = {
      'visits' => true,
      'destination_name' => 'Dest N',
      'ref' => 'DREF',
      'visit_ref' => 'VREF',
      'tags_present' => {
        'tags' => [{ 'label' => 'foo' }],
        'tags_visit' => [{ 'label' => 'bar' }]
      },
      'street' => '1 rue Test',
      'postalcode' => '75001',
      'city' => 'Paris',
      'country' => 'FR',
      'lat' => 48.8566,
      'lng' => 2.3522,
      'detail' => 'Bât. A',
      'comment' => 'Sonner',
      'phone_number' => '+33123456789',
      'destination_duration' => '00:05:00',
      'visit_duration' => '00:07:00'
    }
    assert_equal 'Dest N', Preferences::Catalog::StopList.field_value(stop, 'destination_name')
    assert_equal 'DREF', Preferences::Catalog::StopList.field_value(stop, 'ref')
    assert_equal 'VREF', Preferences::Catalog::StopList.field_value(stop, 'visit_ref')
    assert_equal 'foo', Preferences::Catalog::StopList.field_value(stop, 'tags')
    assert_equal 'bar', Preferences::Catalog::StopList.field_value(stop, 'tags_visit')
    assert_equal '1 rue Test', Preferences::Catalog::StopList.field_value(stop, 'street')
    assert_equal '75001', Preferences::Catalog::StopList.field_value(stop, 'postalcode')
    assert_equal 'Paris', Preferences::Catalog::StopList.field_value(stop, 'city')
    assert_equal 'FR', Preferences::Catalog::StopList.field_value(stop, 'country')
    assert_equal '48.8566', Preferences::Catalog::StopList.field_value(stop, 'lat')
    assert_equal '2.3522', Preferences::Catalog::StopList.field_value(stop, 'lng')
    assert_equal 'Bât. A', Preferences::Catalog::StopList.field_value(stop, 'detail')
    assert_equal 'Sonner', Preferences::Catalog::StopList.field_value(stop, 'comment')
    assert_equal '+33123456789', Preferences::Catalog::StopList.field_value(stop, 'phone_number')
    assert_equal '00:05:00', Preferences::Catalog::StopList.field_value(stop, 'destination_duration')
    assert_equal '00:07:00', Preferences::Catalog::StopList.field_value(stop, 'visit_duration')
  end

  test 'field_value tags is nil when only visit has tags (split payload)' do
    stop = {
      'visits' => true,
      'tags_present' => {
        'tags' => [],
        'tags_visit' => [{ 'label' => 'bar' }]
      }
    }
    assert_nil Preferences::Catalog::StopList.field_value(stop, 'tags')
    assert_equal 'bar', Preferences::Catalog::StopList.field_value(stop, 'tags_visit')
  end

  test 'field_value tags reads legacy single merged list in tags' do
    stop = {
      'visits' => true,
      'tags_present' => { 'tags' => %w[foo] }
    }
    assert_equal 'foo', Preferences::Catalog::StopList.field_value(stop, 'tags')
    assert_nil Preferences::Catalog::StopList.field_value(stop, 'tags_visit')
  end

  test 'field_value destination_name falls back to name for visit stops' do
    stop = { visits: true, name: 'From dest' }
    assert_equal 'From dest', Preferences::Catalog::StopList.field_value(stop, 'destination_name')
  end

  test 'field_value destination_name is nil for non-visit without destination_name' do
    stop = { name: 'Store', visits: false }
    assert_nil Preferences::Catalog::StopList.field_value(stop, 'destination_name')
  end
end
