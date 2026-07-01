# frozen_string_literal: true

module DesignSystem
  class FormsPreview < ApplicationPreview
    include DestinationsHelper

    def text_fields
      render_with_template
    end

    def input_groups
      render_with_template
    end

    def checks_and_switches
      render_with_template
    end

    def selects_and_textareas
      render_with_template
    end

    def filtered_search
      render_with_template
    end

    def validation
      render_with_template
    end

    def range_inputs
      render_with_template
    end
end
end
