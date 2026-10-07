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
//= require jquery.plugin
//= require jquery.timeentry
//= require leaflet_numbered_markers
//= require Leaflet.ControlledBounds
//= require leaflet.pattern

//= require twitter/bootstrap
//= require bootstrap-datepicker
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

// Custom components
//= require utils/active_inactive_drag_drop
//= require utils/active_inactive_drag_drop/drag_handlers_mixin

// jQuery Turbolinks documentation informs to load all scripts before turbolinks
//= require jquery.turbolinks
//= require turbolinks

'use strict';

Turbolinks.setProgressBarDelay(100);

$(document).on('turbolinks:load', function() {
  var startSpinner = function() {
    $('body').addClass('turbolinks_waiting');
  };
  var stopSpinner = function() {
    $('body').removeClass('turbolinks_waiting');
  };
  document.addEventListener("turbolinks:request-start", startSpinner);
  document.addEventListener("turbolinks:request-end", stopSpinner);

  var menuLeft = $('.menu-left');
  var mainContent = $('.main');
  var PLAN_EXPANDED = 'menu-section-plan-expanded';
  var SETTINGS_EXPANDED = 'menu-section-settings-expanded';

  function sectionForCollapse($el) {
    if ($el.closest('#menu-settings').length) return 'settings';
    if ($el.closest('#accordion-menu').length) return 'plan';
    return null;
  }

  function applySectionExpand(section) {
    menuLeft.removeClass(PLAN_EXPANDED + ' ' + SETTINGS_EXPANDED);
    if (section === 'plan') menuLeft.addClass(PLAN_EXPANDED);
    else if (section === 'settings') menuLeft.addClass(SETTINGS_EXPANDED);
  }

  function clearSectionExpand() {
    menuLeft.removeClass(PLAN_EXPANDED + ' ' + SETTINGS_EXPANDED);
  }

  function hideAllMenuCollapses() {
    menuLeft.find('.menu-content.collapse.in').removeClass('in').collapse('hide');
  }

  // Call on hide.bs.collapse; exclude the panel that is closing (still has .in).
  var expandOnShow = null;
  var syncHideTimer = null;

  function syncExpandAfterHide($hiding) {
    var $planOpen = menuLeft.find('#accordion-menu .menu-content.collapse.in');
    var $settingsOpen = menuLeft.find('#menu-settings .menu-content.collapse.in');
    if ($hiding && $hiding.length) {
      $planOpen = $planOpen.not($hiding);
      $settingsOpen = $settingsOpen.not($hiding);
    }
    if ($planOpen.length) applySectionExpand('plan');
    else if ($settingsOpen.length) applySectionExpand('settings');
    else clearSectionExpand();
  }

  menuLeft.on("click", () => {
    menuLeft.addClass("open")
  });

  menuLeft.on('show.bs.collapse', '.menu-content.collapse', function (e) {
    var $panel = $(e.target);
    menuLeft.find('.menu-content.collapse.in').not($panel).removeClass('in');
    expandOnShow = sectionForCollapse($panel);
    if (expandOnShow) applySectionExpand(expandOnShow);
  });

  menuLeft.on('shown.bs.collapse', '.menu-content.collapse', function () {
    expandOnShow = null;
  });

  menuLeft.on('hide.bs.collapse', '.menu-content.collapse', function (e) {
    // Defer: sibling hide runs during another panel's show; keep expand if opening.
    clearTimeout(syncHideTimer);
    var $hiding = $(e.target);
    syncHideTimer = setTimeout(function () {
      if (expandOnShow) {
        applySectionExpand(expandOnShow);
        return;
      }
      syncExpandAfterHide($hiding);
    }, 0);
  });

  menuLeft.on('click', '#menu-plan-burger, #menu-settings-burger', function (e) {
    e.preventDefault();
    e.stopPropagation();
    hideAllMenuCollapses();
    clearSectionExpand();
  });

  mainContent.on("click", () => {
    menuLeft.removeClass("open")
    hideAllMenuCollapses();
    clearSectionExpand();
  });

  Paloma.start();
});

// Fallback for popstate events that Turbolinks ignores (e.g. history.state
// was wiped by location.replace or replaceState from third-party libs).
// Turbolinks only handles popstate when event.state has its restorationIdentifier.
// When missing, the URL changes but the body is never swapped.
(function() {
  var popstateHandled = false;

  document.addEventListener('turbolinks:before-render', function() {
    popstateHandled = true;
  });

  window.addEventListener('popstate', function(event) {
    popstateHandled = false;

    setTimeout(function() {
      if (!popstateHandled) {
        Turbolinks.visit(window.location.href, { action: 'replace' });
      }
    }, 50);
  });
})();
