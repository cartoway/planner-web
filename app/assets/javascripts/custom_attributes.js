'use strict';

import '../../assets/javascripts/scaffolds'

$(document).on('turbolinks:load', function() {
  $('.selectpicker').selectpicker();
});

// Expose custom_attributes_array
window.CustomAttributes = {
  custom_attributes_array: function() {
    var i = 0;
    const element = $('#default_list');
    if (element.length) {
      i = element.find('default-value-row').length;
    }

    $('.btn-remove').on('click', function() {
      var button_id = $(this).closest('.default-value-row').attr('id').split('_').pop();
      $('#row_'+ button_id).remove();
    })

    $('#add_row').on('click', function() {
      addElement();
    });

    function addElement() {
      if (element) {
        element.append('<div class="default-value-row input-group" id="row_added_' + i + '"><input id="custom_attribute_default_value" class="form-control" name="custom_attribute[default_value][]" required="true"><a id="delete_added_' + i + '" class="input-group-addon btn btn-danger btn-sm btn-remove"><i class="fa fa-trash fa-fw"></i> ' + I18n.t('all.verb.destroy') + ' </a></div>')
        $('.btn-remove').on('click', function() {
          var button_id = $(this).closest('.default-value-row').attr('id').split('_').pop();
          $('#row_added_'+ button_id).remove();
        })
        i++;
      }
    }
  }
}

const update_default_value = function() {
  $('#custom_attribute_object_type').on('change', function() {
    var form_id = $('.edit_custom_attribute').attr('id');
    var formData = $('.edit_custom_attribute, .new_custom_attribute').serialize();
    var url = form_id ?
      '/custom_attributes/' + form_id.split('_').pop() + '/update_default_value_partial' :
      '/reset_default_value_partial'
    $.ajax({
      url: url,
      type: form_id ? 'PATCH' : 'POST',
      data: formData,
      dataType: 'script'
    });
  });
}

const update_object_class_fields = function() {
  // Initialize hidden fields on page load
  var currentValue = $('#custom_attribute_object_class_with_related_field').val();
  var objectClassField = $('#custom_attribute_object_class');
  var relatedFieldField = $('#custom_attribute_related_field');

  if (currentValue) {
    if (currentValue.includes(':')) {
      var parts = currentValue.split(':', 2);
      objectClassField.val(parts[0]);
      relatedFieldField.val(parts[1] || '');
    } else {
      objectClassField.val(currentValue);
      relatedFieldField.val('');
    }
  }

  // Update hidden fields when select changes
  $('#custom_attribute_object_class_with_related_field').on('change', function() {
    var combinedValue = $(this).val();

    if (combinedValue && combinedValue.includes(':')) {
      var parts = combinedValue.split(':', 2);
      objectClassField.val(parts[0]);
      relatedFieldField.val(parts[1] || '');
    } else {
      objectClassField.val(combinedValue || '');
      relatedFieldField.val('');
    }
  });
}

Paloma.controller('CustomAttributes', {
  new: function() {
    // custom_attributes_form();
    CustomAttributes.custom_attributes_array();
    update_default_value();
    update_object_class_fields();
  },
  create: function() {
    // custom_attributes_form();
    CustomAttributes.custom_attributes_array();
    update_default_value();
    update_object_class_fields();
  },
  edit: function() {
    // custom_attributes_form();
    CustomAttributes.custom_attributes_array();
    update_default_value();
    update_object_class_fields();
  },
  update: function() {
    // custom_attributes_form();
    CustomAttributes.custom_attributes_array();
    update_default_value();
    update_object_class_fields();
  }
});
