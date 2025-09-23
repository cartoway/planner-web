/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb
'use strict';

// FIXME: jQuery 3 not working with pnotify
import 'expose-loader?$!expose-loader?jQuery!jquery';
import 'jquery-ujs';

import 'select2';
import 'select2/dist/js/i18n/fr';
import 'select2/dist/js/i18n/en';
import 'select2/dist/js/i18n/es';
import 'select2/dist/js/i18n/pt';
import 'select2/dist/js/i18n/he';

import 'bootstrap-select';

import 'bootstrap-filestyle';

import 'bootstrap-datepicker';
import 'bootstrap-datepicker/dist/locales/bootstrap-datepicker.fr.min';
import 'bootstrap-datepicker/dist/locales/bootstrap-datepicker.fr-CH.min';
import 'bootstrap-datepicker/dist/locales/bootstrap-datepicker.en-GB.min';
import 'bootstrap-datepicker/dist/locales/bootstrap-datepicker.pt-BR.min';
import 'bootstrap-datepicker/dist/locales/bootstrap-datepicker.es.min';
// he not available, yet
// pt-PT not available, yet

import 'bootstrap-slider';

import 'jquery-ui/ui/widgets/autocomplete';
import 'jquery-ui/ui/widgets/sortable';
import 'jquery-ui/ui/widgets/dialog';

import 'tablesorter';
import 'tablesorter/dist/js/widgets/widget-filter-formatter-html5.min';
import 'tablesorter/dist/js/widgets/widget-filter-formatter-jui.min';
import 'tablesorter/dist/js/widgets/widget-scroller.min';
import 'tablesorter/dist/js/widgets/widget-columnSelector.min';
import 'tablesorter/dist/js/widgets/widget-pager.min';

import 'jquery-simplecolorpicker';

import 'expose-loader?PNotify!pnotify';
import 'pnotify/dist/pnotify.buttons';
import 'pnotify/dist/pnotify.nonblock';
import 'pnotify/dist/pnotify.desktop';

import 'expose-loader?L!leaflet';
import 'leaflet-polylineoffset';
import 'leaflet.markercluster';
import 'leaflet-control-geocoder';
import 'leaflet-hash';
import 'sidebar-v2/js/leaflet-sidebar';
import 'polyline-encoded';
import 'leaflet-lasso';
import '@geoman-io/leaflet-geoman-free';

import '../../assets/javascripts/screenLog.js.erb';

// Hack for leaflet working with webpacker (https://github.com/Leaflet/Leaflet/issues/4968)

import marker from 'leaflet/dist/images/marker-icon.png';
import marker2x from 'leaflet/dist/images/marker-icon-2x.png';
import markerShadow from 'leaflet/dist/images/marker-shadow.png';

// Remove leaflet default icon url
delete L.Icon.Default.prototype._getIconUrl;

// Re-setup leaflet images urls
L.Icon.Default.mergeOptions({
    iconRetinaUrl: marker2x,
    iconUrl: marker,
    shadowUrl: markerShadow
});

// Manage flash messages
$(document).on('turbolinks:load', function () {
  hideNotices();

  $('.flash-message').each((index, element) => {
    const $element = $(element);
    const level = $element.data('level');
    const content = $element.html().trim();

    if (level === 'alert' || level === 'error') {
      stickyError(content);
    } else if (level === 'notice') {
      notice(content);
    } else {
      notify(content);
    }
  });
});
