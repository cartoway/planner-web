# frozen_string_literal: true

require 'test_helper'

class DesignSystem::TablesPreviewTest < ActiveSupport::TestCase
  test 'destinations_list render_args expose customer and list data to the template' do
    args = DesignSystem::TablesPreview.render_args(:destinations_list)

    assert args[:assigns].present?
    assert args[:assigns][:customer].present?
    assert args[:assigns][:destinations].present?
    assert args[:assigns][:destinations_list_columns].present?
    assert args[:assigns][:pagination].present?
    assert_includes args[:assigns][:destinations_list_columns], 'ref'
  end
end
