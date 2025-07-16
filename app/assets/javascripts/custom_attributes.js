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
    console.log(element);
    if (element.length) {
      console.log(element.find('default-value-row'));
      i = element.find('default-value-row').length;
    }

    $('.btn-remove').on('click', function() {
      var button_id = $(this).closest('.default-value-row').attr('id').split('_').pop();
      console.log(button_id);
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

Paloma.controller('CustomAttributes', {
  new: function() {
    custom_attributes_form();
    CustomAttributes.custom_attributes_array();
    update_default_value();
  },
  create: function() {
    custom_attributes_form();
    CustomAttributes.custom_attributes_array();
    update_default_value();
  },
  edit: function() {
    custom_attributes_form();
    CustomAttributes.custom_attributes_array();
    update_default_value();
  },
  update: function() {
    custom_attributes_form();
    CustomAttributes.custom_attributes_array();
    update_default_value();
  }
});
