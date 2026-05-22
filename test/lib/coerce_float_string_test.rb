# frozen_string_literal: true

require 'test_helper'

class CoerceFloatStringTest < ActiveSupport::TestCase
  test 'parse accepts french decimal comma' do
    assert_in_delta 49.173, CoerceFloatString.parse('49,173', locale: :fr)
    assert_in_delta(-0.326613, CoerceFloatString.parse('-0,326613', locale: :fr))
  end

  test 'parse accepts anglo decimal dot' do
    assert_in_delta 49.173, CoerceFloatString.parse('49.173', locale: :en)
    assert_in_delta(-0.326613, CoerceFloatString.parse('-0.326613', locale: :en))
  end

  test 'parse accepts french thousands with comma decimal' do
    assert_in_delta 1234.567, CoerceFloatString.parse("1\u202f234,567", locale: :fr)
    assert_in_delta 1234.567, CoerceFloatString.parse('1 234,567', locale: :fr)
  end

  test 'parse accepts anglo thousands with dot decimal' do
    assert_in_delta 1234.567, CoerceFloatString.parse('1,234.567', locale: :en)
  end

  test 'parse returns nil for blank strings' do
    assert_nil CoerceFloatString.parse('')
    assert_nil CoerceFloatString.parse('   ')
  end

  test 'parse passes through numeric values' do
    assert_in_delta 48.856, CoerceFloatString.parse(48.856)
    assert_kind_of Float, CoerceFloatString.parse(30)
  end
end
