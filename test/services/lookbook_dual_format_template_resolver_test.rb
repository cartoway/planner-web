# frozen_string_literal: true

require 'test_helper'

class LookbookDualFormatTemplateResolverTest < ActiveSupport::TestCase
  Scenario = Struct.new(:name, :preview, keyword_init: true)
  Preview = Struct.new(:preview_class, keyword_init: true)

  test 'reads haml source from disk' do
    scenario = Scenario.new(
      name: 'variants',
      preview: Preview.new(preview_class: DesignSystem::ButtonsPreview)
    )

    haml = LookbookDualFormatTemplateResolver.template_source(scenario, :haml)

    assert_match(/Button variants/, haml)
    assert_match %r{buttons_preview/variants\.html\.haml\z}, LookbookDualFormatTemplateResolver.haml_template_path(scenario).to_s
  end

  test 'erb source is converted from haml' do
    scenario = Scenario.new(
      name: 'destinations_list',
      preview: Preview.new(preview_class: DesignSystem::TablesPreview)
    )

    erb = LookbookDualFormatTemplateResolver.template_source(scenario, :erb)

    assert_match(/list_frame/, erb)
    assert_match(/<%/, erb)
    assert_no_match(/%code/, erb)
  end
end
