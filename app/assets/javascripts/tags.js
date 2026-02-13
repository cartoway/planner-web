// Copyright © Mapotempo, 2013-2017
//
// This file is part of Mapotempo.
//
// Mapotempo is free software. You can redistribute it and/or
// modify since you respect the terms of the GNU Affero General
// Public License as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// Mapotempo is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Mapotempo. If not, see:
// <http://www.gnu.org/licenses/agpl.html>
//
'use strict';

import { customColorInitialize } from '../../assets/javascripts/scaffolds';
import { beforeSendWaiting, completeWaiting, ajaxError } from '../../assets/javascripts/ajax';

// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.
const tags_form = function() {
  $('#tag_color').simplecolorpicker({
    theme: 'fontawesome'
  });

  customColorInitialize('#tag_color');

  //for turbolinks, when clicking on link_to
  $('.selectpicker').selectpicker();
};

Paloma.controller('Tags', {
  new: function() {
    tags_form();
  },
  create: function() {
    tags_form();
  },
  edit: function() {
    tags_form();
  },
  update: function() {
    tags_form();
  }
});

export const selectTag = function(event) {
  if (event.params.args.data.newTag) {
    event.preventDefault();
    $.ajax({
      type: "post",
      data: '{"label": "' + event.params.args.data.id + '", "ref": "#' + event.params.args.data.id + '"}',
      contentType: 'application/json',
      url: '/api/0.1/tags.json',
      success: function(data) {
        const $select = $(event.target);
        $select.parent().find('.select2-search__field').val('');

        $select.find('option').filter(function() { this.value == data.label }).remove();
        $select.append(new Option(data.label, data.id, false, false)).trigger('change');

        const selectedOptions = $select.select2('data').map(function(el) { return el.id });
        selectedOptions.push(data.id.toString());

        $select.val(selectedOptions).trigger('change');
        $select.select2('close');
      },
      beforeSend: beforeSendWaiting,
      complete: completeWaiting,
      error: ajaxError
    });
  }
}
