# frozen_string_literal: true

# Vendored from haml_to_erb (MIT) — https://github.com/kurioscreative/haml_to_erb
require_relative 'lookbook_haml_to_erb/converter'

module LookbookHamlToErbConverter
  module_function

  def convert(haml_source)
    LookbookHamlToErb::Converter.new(haml_source).convert
  rescue StandardError => e
    "<%# HAML→ERB conversion failed: #{e.class}: #{e.message} %>\n"
  end
end
