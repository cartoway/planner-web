// Copyright © Mapotempo, 2015
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

import { mapInitialize, initializeMapHash } from '../../scaffolds';
import { beforeSendWaiting, completeWaiting, ajaxError, mustache_i18n } from '../../ajax';
import { api_web_v01_display_destinations_ } from './destinations';

const api_web_v01_zones_index = function(params) {
  var progressBar = Turbolinks.enableProgressBar();
  progressBar && progressBar.advanceTo(25);

  var map = mapInitialize(params);
  L.control.attribution({
    prefix: false
  }).addTo(map);
  L.control.scale({
    imperial: false
  }).addTo(map);

  var caption = L.DomUtil.get('zones-caption');
  if (caption) {
    caption.classList.add('leaflet-bar');
    var control_caption = L.Control.extend({
      options: {
        position: 'bottomright'
      },
      onAdd: function(map) {
        var container = caption;
        L.DomEvent.disableClickPropagation(container);
        return container;
      }
    });
    map.addControl(new control_caption());
  }

  map.markersLayers = L.featureGroup();
  map.storesLayers = L.featureGroup();
  var featureGroup = L.featureGroup();

  map.addLayer(featureGroup).addLayer(map.storesLayers).addLayer(map.markersLayers);

  var fitBounds = initializeMapHash(map, true);

  const setColor = function(polygon, vehicle_id, speed_multiplier) {
    polygon.setStyle((speed_multiplier === 0) ? {
      color: '#FF0000',
      fillColor: '#707070',
      weight: 5,
      dashArray: '10, 10',
      fillPattern: stripes
    } : {
      color: (vehicle_id ? params.vehicles_map[vehicle_id].color : '#707070'),
      fillColor: null,
      weight: 2,
      dashArray: 'none',
      fillPattern: null
    });
  };
  var stripes = new L.StripePattern({
    color: '#FF0000',
    angle: -45
  });
  stripes.addTo(map);

  var zoneGeometry = L.GeoJSON.extend({
    addOverlay: function(zone) {
      var that = this;
      var labelLayer = (new L.layerGroup()).addTo(map);
      var labelMarker;
      this.on('mouseover', function(e) {
        that.setStyle({
          opacity: 0.9,
          weight: (zone.speed_multiplier === 0) ? 5 : 3
        });
        if (zone.name) labelMarker = L.marker(that.getBounds().getCenter(), {
          icon: L.divIcon({
            className: 'label',
            html: zone.name,
            iconSize: [100, 40]
          })
        }).addTo(labelLayer);
      });
      this.on('mouseout', function(e) {
        that.setStyle({
          opacity: 0.5,
          weight: (zone.speed_multiplier === 0) ? 5 : 2
        });
        if (labelMarker) labelLayer.removeLayer(labelMarker);
        labelMarker = null
      });
      return this;
    }
  });

  const addZone = function(zone, geom) {
    var geoJsonLayer;
    if (geom instanceof L.GeoJSON) {
      geoJsonLayer = geom;
      geom = geom.getLayers()[0];
    } else {
      geoJsonLayer = (new zoneGeometry()).addOverlay(zone);
      geoJsonLayer.addLayer(geom);
    }
    featureGroup.addLayer(geom);
  };

  const displayZoning = function(data) {
    map.storesLayers.clearLayers();
    $.each(data.stores, function(i, store) {
      store.store = true;
      store.i18n = mustache_i18n;
      if ($.isNumeric(store.lat) && $.isNumeric(store.lng)) {
        var m = L.marker(new L.LatLng(store.lat, store.lng), {
          icon: L.divIcon({
            html: '<i class="fa ' + (store.icon || 'fa-home') + ' ' + map.iconSize[store.icon_size || 'large'].name + ' store-icon" style="color: ' + (store.color || 'black') + ';"></i>',
            iconSize: new L.Point(map.iconSize[store.icon_size || 'large'].size, map.iconSize[store.icon_size || 'large'].size),
            iconAnchor: new L.Point(map.iconSize[store.icon_size || 'large'].size / 2, map.iconSize[store.icon_size || 'large'].size / 2),
            popupAnchor: new L.Point(0, -Math.floor(map.iconSize[store.icon_size || 'large'].size / 2.5)),
            className: 'store-icon-container'
          })
        }).addTo(map.storesLayers).bindPopup(SMT['stops/show'](store));
        m.on('mouseover', function(e) {
          m.openPopup();
        }).on('mouseout', function(e) {
          m.closePopup();
        });
      }
    });

    $.each(data.zoning, function(index, zone) {
      var geom = (new zoneGeometry(JSON.parse(zone.polygon))).addOverlay(zone);
      setColor(geom, zone.vehicle_id, zone.speed_multiplier);
      addZone(zone, geom);
    });

    if (markersGroup) {
      markersGroup.showAllDestinations(destinationsParams);
    }
    var bounds = featureGroup.getBounds();
    if (bounds && bounds.isValid() && fitBounds) {
      map.fitBounds(bounds, {
        maxZoom: 15,
        padding: [20, 20]
      });
    }
  };

  progressBar && progressBar.advanceTo(50);
  var ajaxParams = {};
  var destinationsParams = {};
  var markersGroup;

  if (params.zone_ids) ajaxParams.ids = params.zone_ids.join(',');
  if (params.destination_ids && !params.destinations) destinationsParams.destination_ids = params.destination_ids.join(',');
  if (params.vehicle_usage_set_id) ajaxParams.vehicle_usage_set_id = params.vehicle_usage_set_id;
  if (params.store_ids) ajaxParams.store_ids = params.store_ids.join(',');

  if (destinationsParams.destination_ids || params.destinations) {

    markersGroup = new RoutesLayer(null, {
      routes: params.routes_array,
      colorsByRoute: params.colors_by_route,
      appBaseUrl: '/api-web/0.1/',
      withPolylines: false,
      popupOptions: {
        isoline: false,
      },
      disableClusters: true,
    }).addTo(map);
    L.disableClustersControl(map, markersGroup);
  }

  $.ajax({
    url: '/api-web/0.1/zonings/' + params.zoning_id + '/zones.json',
    method: params.method,
    data: ajaxParams,
    beforeSend: beforeSendWaiting,
    success: function(data) {
      if (data.zoning && data.zoning.length) {
        displayZoning(data);
      } else {
        stickyError(I18n.t('api_web.v01.zones.index.none_zones'));
      }
      progressBar && progressBar.done();
    },
    complete: completeWaiting,
    error: ajaxError
  });
};

Paloma.controller('ApiWeb/V01/Zones', {
  index: function() {
    api_web_v01_zones_index(this.params);
  }
});
