# frozen_string_literal: true

require 'test_helper'

class DestinationSearchParserTest < ActiveSupport::TestCase
  test 'parse returns empty array for blank query' do
    assert_equal [], DestinationSearchParser.parse('')
    assert_equal [], DestinationSearchParser.parse('   ')
    assert_equal [], DestinationSearchParser.parse(nil)
  end

  test 'parse extracts key value pairs' do
    result = DestinationSearchParser.parse('name:Dupont')
    assert_equal [{ key: 'name', value: 'Dupont' }], result
  end

  test 'parse extracts multiple key value pairs' do
    result = DestinationSearchParser.parse('name:Dupont city:Lyon')
    assert_equal [
      { key: 'name', value: 'Dupont' },
      { key: 'city', value: 'Lyon' }
    ], result
  end

  test 'parse keeps spaces inside filter values' do
    result = DestinationSearchParser.parse('name:Jean Dupont')
    assert_equal [{ key: 'name', value: 'Jean Dupont' }], result
  end

  test 'parse keeps spaces in values across multiple filters' do
    result = DestinationSearchParser.parse('name:Jean Dupont city:Lyon')
    assert_equal [
      { key: 'name', value: 'Jean Dupont' },
      { key: 'city', value: 'Lyon' }
    ], result
  end

  test 'parse keeps spaces in plain text fallback search' do
    result = DestinationSearchParser.parse('Jean Dupont')
    assert_equal [{ key: 'q', value: 'Jean Dupont' }], result
  end

  test 'parse uses fallback for plain text without colon' do
    result = DestinationSearchParser.parse('Paris')
    assert_equal [{ key: 'q', value: 'Paris' }], result
  end

  test 'parse ignores invalid keys' do
    result = DestinationSearchParser.parse('invalid:value')
    assert_equal [], result
  end

  test 'parse accepts all allowed keys' do
    query = 'ref:D001 name:Test address:Rue city:Lyon postalcode:69001 country:France phone:01 comment:Note tags:urgent visit_ref:V1 visit_tags:delivery'
    result = DestinationSearchParser.parse(query)
    assert_equal 11, result.size
    assert_includes result.map { |r| r[:key] }, 'ref'
    assert_includes result.map { |r| r[:key] }, 'tags'
  end

  test 'parse accepts localized keys in French' do
    I18n.with_locale(:fr) do
      result = DestinationSearchParser.parse('nom:Dupont ville:Lyon')
      assert_equal 2, result.size
      assert_equal 'name', result[0][:key]
      assert_equal 'Dupont', result[0][:value]
      assert_equal 'city', result[1][:key]
      assert_equal 'Lyon', result[1][:value]
    end
  end
end
