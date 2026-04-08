// Copyright © Cartoway, 2026
//
// This file is part of Cartoway Planner.
//
// Cartoway Planner is free software. You can redistribute it and/or
// modify since you respect the terms of the GNU Affero General
// Public License as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Cartoway Planner. If not, see:
// <http://www.gnu.org/licenses/agpl.html>
//
'use strict';

import '../scaffolds';

// Icon field uses bootstrap-select (class selectpicker); init on each Turbolinks visit.
$(document).on('turbolinks:load', function() {
  var $icon = $('select.selectpicker[name="role[icon]"]');
  if (!$icon.length) {
    return;
  }
  $icon.each(function() {
    var $el = $(this);
    if ($el.parent().hasClass('bootstrap-select')) {
      $el.selectpicker('destroy');
    }
    $el.selectpicker();
  });
});

$(document).on('turbolinks:before-cache', function() {
  $('select.selectpicker[name="role[icon]"]').each(function() {
    var $el = $(this);
    if ($el.parent().hasClass('bootstrap-select')) {
      $el.selectpicker('destroy');
    }
  });
});
