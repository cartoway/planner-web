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

import { mapInitialize } from '../../assets/javascripts/scaffolds';

const user_edit_settings = function(params) {
  var available_layers = params.map_available_layers;

  var map = mapInitialize(params);
  L.control.attribution({
    prefix: false
  }).addTo(map);

  $('[name=user\\[layer_id\\]]').change(function(event) {
    map.removeLayer(map.tileLayer);
    map.tileLayer = L.tileLayer(available_layers[event.target.value].url, {
      maxZoom: 19,
      attribution: available_layers[event.target.value].attribution
    });
    map.addLayer(map.tileLayer);
  });

  $('.select2').select2();
};

Paloma.controller('Users', {
  edit: function() {
    user_edit_settings(this.params);
  },
  update: function() {
    user_edit_settings(this.params);
  }
});
