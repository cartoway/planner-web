// Copyright © Cartoway, 2025
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

var _map,
    _routesLayer;

function initialize(map, routesLayer) {
  _map = map;
  _routesLayer = routesLayer;
  return this;
}

function extractMarkersData() {
  var markers = [];

  if (_routesLayer && _routesLayer.clustersByRoute) {
    Object.keys(_routesLayer.clustersByRoute).forEach(function(routeId) {
      var cluster = _routesLayer.clustersByRoute[routeId];
      if (cluster && cluster.getLayers) {
        var clusterMarkers = cluster.getLayers();
        clusterMarkers.forEach(function(layer) {
          if (layer.getLatLng && layer.properties) {
            markers.push({
              id: layer.properties.stop_id,
              type: 'stop',
              lat: layer.getLatLng().lat,
              lng: layer.getLatLng().lng,
              route_id: layer.properties.route_id,
              stop_id: layer.properties.stop_id,
              properties: layer.properties
            });
          }
        });
      }
    });
  }

  if (_routesLayer && _routesLayer.markerStores) {
    Object.keys(_routesLayer.markerStores).forEach(function(storeId) {
      var marker = _routesLayer.markerStores[storeId];
      if (marker && marker.getLatLng && marker.properties) {
        markers.push({
          id: marker.properties.store_id,
          type: 'store',
          lat: marker.getLatLng().lat,
          lng: marker.getLatLng().lng,
          route_id: marker.properties.route_id,
          properties: marker.properties
        });
      }
    });
  }

  if (markers.length === 0 && _routesLayer && _routesLayer.getSelectableLayers) {
    var layers = _routesLayer.getSelectableLayers();
    layers.forEach(function(layer) {
      if (layer.getLatLng && layer.properties) {
        markers.push({
          id: layer.properties.stop_id,
          type: 'stop',
          lat: layer.getLatLng().lat,
          lng: layer.getLatLng().lng,
          route_id: layer.properties.route_id,
          stop_id: layer.properties.stop_id,
          properties: layer.properties
        });
      }
    });
  }

  return markers;
}

window.MapDataExtractor = {
  initialize: initialize,
  extractMarkersData: extractMarkersData
};
