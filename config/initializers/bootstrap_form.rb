module BootstrapForm
  module FormGroup
    def form_group_default_class
      (layout == :inline ? "col" : "")
    end
  end

  module Helpers
    module Bootstrap
      def input_group_content(content)
        return content if content.include?("btn")

        tag.span(content, class: "input-group-addon")
      end
    end
  end

  class FormBuilder
    def default_label_col
      'col-md-offset-2 col-md-7'
    end

    def default_control_col
      'col-md-offset-2 col-md-8 field'
    end

    def default_layout
      :horizontal
    end

    def render_haml(haml, locals = {})
      Haml::Template.new { haml.strip_heredoc }.render(self, locals)
    end

    def submit(action: nil, message: nil, icon: nil, button: nil, title: nil, disable_with: nil)
      action = action == 'new' ? 'create' : 'update'
      object = self.object.class.name.underscore

      output = render_haml <<-HAML, object: object, action: action, message: message, icon: icon, disable_with: disable_with
        .row.form-group{ id: "#{object}_div_input" }
          .col-md-offset-2.col-md-6
            %button{ name: 'button', type: 'submit', class: "#{button || 'btn btn-primary'}", title: "#{title}", data: { disable_with: "#{disable_with}"}}
              %i.fa{ class: "#{icon || 'fa-floppy-disk'}" }
              = message || I18n.t("helpers.submit.#{action}", model: I18n.t("activerecord.models.#{object.pluralize}.one"))
      HAML
      output.html_safe
    end
  end
end
