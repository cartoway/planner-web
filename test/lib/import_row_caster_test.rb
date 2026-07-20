# frozen_string_literal: true

require 'test_helper'
require 'importer_base'
require 'import_row_caster'

class ImportRowCasterTest < ActiveSupport::TestCase
  test 'casts float with french decimal comma' do
    I18n.with_locale(:fr) do
      row = { lat: '49,173', revenue: '12,5' }
      columns = { lat: { type: :float }, revenue: { type: :float } }

      ImportRowCaster.cast_row!(row, columns)

      assert_in_delta 49.173, row[:lat]
      assert_in_delta 12.5, row[:revenue]
    end
  end

  test 'casts quantity columns as float' do
    I18n.with_locale(:fr) do
      row = { quantity1: '1,25', pickup1: '2', delivery1: '3,5' }
      columns = {
        quantity1: { type: :float },
        pickup1: { type: :float },
        delivery1: { type: :float }
      }

      ImportRowCaster.cast_row!(row, columns)

      assert_in_delta 1.25, row[:quantity1]
      assert_in_delta 2.0, row[:pickup1]
      assert_in_delta 3.5, row[:delivery1]
    end
  end

  test 'casts hour to seconds via ScheduleType' do
    row = { duration: '01:30' }
    columns = { duration: { type: :hour } }

    ImportRowCaster.cast_row!(row, columns)

    assert_equal 5400, row[:duration]
  end

  test 'casts yes_no and leaves blank boolean as nil' do
    row = { active: 'oui', flag: '' }
    columns = { active: { type: :yes_no }, flag: { type: :yes_no } }

    I18n.with_locale(:fr) do
      ImportRowCaster.cast_row!(row, columns)
    end

    assert_equal true, row[:active]
    assert_nil row[:flag]
  end

  test 'keeps postalcode as string with leading zeros' do
    row = { postalcode: '01000' }
    columns = { postalcode: { type: :string } }

    ImportRowCaster.cast_row!(row, columns)

    assert_equal '01000', row[:postalcode]
  end

  test 'raises ImportInvalidRow on invalid float' do
    row = { lat: 'abc' }
    columns = { lat: { type: :float } }

    assert_raises(ImportInvalidRow) do
      ImportRowCaster.cast_row!(row, columns)
    end
  end

  test 'passes through already typed values from API' do
    row = { lat: 48.85, priority: 2, duration: 600, tags: [1, 2] }
    columns = {
      lat: { type: :float },
      priority: { type: :integer },
      duration: { type: :hour },
      tags: { type: :tags }
    }

    ImportRowCaster.cast_row!(row, columns)

    assert_in_delta 48.85, row[:lat]
    assert_equal 2, row[:priority]
    assert_equal 600, row[:duration]
    assert_equal [1, 2], row[:tags]
  end

  test 'casts custom attribute boolean and array option as string' do
    row = { 'custom_attributes_visit[flag]': 'oui', 'custom_attributes_visit[choice]': 'A' }
    columns = {
      'custom_attributes_visit[flag]': { type: :boolean },
      'custom_attributes_visit[choice]': { type: :string }
    }

    I18n.with_locale(:fr) do
      ImportRowCaster.cast_row!(row, columns)
    end

    assert_equal true, row[:'custom_attributes_visit[flag]']
    assert_equal 'A', row[:'custom_attributes_visit[choice]']
  end
end
