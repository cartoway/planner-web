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
// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//

// Common
//= require i18n
//= require i18n/translations

// Custom gems
//= require jquery.timeentry
//= require leaflet_numbered_markers
//= require Leaflet.ControlledBounds
//= require leaflet.pattern

//= require twitter/bootstrap
//= require bootstrap-wysihtml5
//= require bootstrap-wysihtml5/locales/fr-FR.js
//= require bootstrap-wysihtml5/locales/en-US.js
// require bootstrap-wysihtml5/locales/id.js // Not available, yet
// require bootstrap-wysihtml5/locales/he.js // Not available, yet
// require bootstrap-wysihtml5/locales/pt-PT.js // Not available, yet
// he and pt-PT not available, yet

// pnotify use I18n
//= require pnotify.init

//= require paloma

//= require mustache
//= require_tree ../../templates

// jQuery Turbolinks documentation informs to load all scripts before turbolinks
//= require jquery.turbolinks
//= require turbolinks

'use strict';

Turbolinks.enableProgressBar();
// bug in Firefox 40 when printing multi pages with progress bar
window.onbeforeprint = function() {
  Turbolinks.enableProgressBar(false);
};
window.onafterprint = function() {
  Turbolinks.enableProgressBar();
};

$(document).ready(function() {
  var startSpinner = function() {
    $('body').addClass('turbolinks_waiting');
  };
  var stopSpinner = function() {
    $('body').removeClass('turbolinks_waiting');
  };
  $(document).on("page:fetch", startSpinner);
  $(document).on("page:receive", stopSpinner);

  var menuLeft = $('.menu-left');
  var mainContent = $('.main');

  menuLeft.on("click", () => {
    menuLeft.addClass("open")
  });

  $('.menu-content').on('show.bs.collapse', function () {
    $('.menu-content.in').removeClass('in');
  });

  mainContent.on("click", () => {
    menuLeft.removeClass("open")
    $('.menu-content.in').removeClass('in');
  })

  Paloma.start();
});

// $(document).on('page:restore', function() {
//   Paloma.start();
// });
