// Copyright © Mapotempo, 2015-2017
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

import { RoutesLayer } from '../../routes_layers'
import { mapInitialize, initializeMapHash } from '../../scaffolds';
import { destinations_edit } from '../../destinations';

const api_web_v01_destinations_index = function(params, api) {
  var markersGroup;
  var map = mapInitialize(params);
  markersGroup = new RoutesLayer(null, {
    routes: params.routes_array, // Needed for outdated
    colorsByRoute: params.colors_by_route,
    appBaseUrl: '/api-web/0.1/',
    withPolylines: false,
    popupOptions: {
      isoline: false,
    },
    disableClusters: params.disable_clusters,
  }).addTo(map);

  L.disableClustersControl(map, markersGroup);

  Turbolinks.setProgressBarDelay(25);

  var ids = params.ids;

  L.control.attribution({
    prefix: false
  }).addTo(map);
  L.control.scale({
    imperial: false
  }).addTo(map);

  // var markersLayers = map.markersLayers = L.featureGroup();
  var markersLayers = map.markersLayers = new L.MarkerClusterGroup({
    showCoverageOnHover: false,
    removeOutsideVisibleBounds: true,
    disableClusteringAtZoom: (api === 'destinations' && !params.disable_clusters) ? 19 : 0
  });
  map.addLayer(markersLayers);

  var fitBounds = initializeMapHash(map, true);

  Turbolinks.setProgressBarDelay(50);
  var ajaxParams = {};
  if (ids) ajaxParams.ids = ids.join(',');
  if (params.store_ids) ajaxParams.store_ids = params.store_ids.join(',');

  if (api === 'destinations') {
    var storesLayers = map.storesLayers = L.featureGroup();
    storesLayers.addTo(map);

    markersGroup.showAllDestinations(ajaxParams, function() {
      if (fitBounds) {
        var bounds = markersGroup.getBounds();
        if (bounds.isValid()) {
          map.fitBounds(bounds, {
            maxZoom: 15,
            padding: [20, 20]
          });
        }
      }
    });
  } else if (api == 'stores') {
    markersGroup.showAllStores(ajaxParams, function() {
      if (fitBounds) {
        var bounds = markersGroup.getBounds();
        if (bounds.isValid()) {
          map.fitBounds(bounds, {
            maxZoom: 15,
            padding: [20, 20]
          });
        }
      }
    });
  }
};

Paloma.controller('ApiWeb/V01/Destinations', {
  edit_position: function() {
    destinations_edit(this.params, 'destinations');
  },
  update_position: function() {
    destinations_edit(this.params, 'destinations');
  },
  index: function() {
    api_web_v01_destinations_index(this.params, 'destinations');
  }
});

Paloma.controller('ApiWeb/V01/Stores', {
  edit_position: function() {
    destinations_edit(this.params, 'stores');
  },
  update_position: function() {
    destinations_edit(this.params, 'stores');
  },
  index: function() {
    api_web_v01_destinations_index(this.params, 'stores');
  }
});

Paloma.controller('ApiWeb/V01/Store').prototype.by_distance = function() {
  api_web_v01_destinations_index(this.params, 'stores');
};

