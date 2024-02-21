module BootstrapForm
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
      Haml::Engine.new(haml.strip_heredoc, format: :html5).render(self, locals)
    end

    def submit(action: nil, message: nil, icon: nil, button: nil, title: nil)
      action = action == 'new' ? 'create' : 'update'
      object = self.object.class.name.snakecase

      render_haml <<-HAML, object: object, action: action, message: message, icon: icon
        .form-group{ id: "#{object}_div_input" }
          .col-md-offset-2.col-md-6
            %button{ name: 'button', type: 'submit', class: "#{button || 'btn btn-primary'}", title: "#{title}" }
              %i.fa{ class: "#{icon || 'fa-floppy-disk'}" }
              = message || I18n.t("helpers.submit.#{action}", model: I18n.t("activerecord.models.#{object}s.one"))
      HAML
    end
  end
end
