// Copyright © Mapotempo, 2016
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

import {
  plannings_edit
} from '../../plannings';

const api_web_v01_plannings_print = function (params) {
  $('.btn-print').click(function () {
    window.print();
  });
};

Paloma.controller('ApiWeb/V01/Plannings', {
  edit: function () {
    this.params.apiWeb = true;
    plannings_edit(this.params);
  },
  print: function () {
    api_web_v01_plannings_print(this.params);
  }
});
