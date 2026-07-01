# frozen_string_literal: true

# Lookbook preview templates: canonical HAML on disk; ERB shown in the inspector is converted on the fly.
module LookbookDualFormatTemplateResolver
  PREVIEW_ROOT = Rails.root.join('test/components/previews')

  module_function

  def scenario_base_name(scenario)
    scenario.name.to_s.sub(/_erb\z/, '')
  end

  def preview_template_dir(scenario)
    class_name = scenario.preview.preview_class.name
    folder = class_name.deconstantize.underscore
    preview_slug = class_name.demodulize.sub(/Preview\z/, '').underscore
    PREVIEW_ROOT.join(folder, "#{preview_slug}_preview")
  end

  def haml_template_path(scenario)
    dir = preview_template_dir(scenario)
    base = scenario_base_name(scenario)
    Pathname.glob(dir.join("#{base}.html.haml")).first
  end

  def template_source(scenario, format)
    path = haml_template_path(scenario)
    return nil unless path

    haml = File.read(path)
    return haml if format.to_sym == :haml

    require Rails.root.join('lib/lookbook_haml_to_erb')
    LookbookHamlToErbConverter.convert(haml)
  end
end
