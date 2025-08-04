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

export const getGeomanTranslations = () => {
  return {
    tooltips: {
      placeMarker: I18n.t('geoman.tooltips.placeMarker'),
      firstVertex: I18n.t('geoman.tooltips.firstVertex'),
      continueLine: I18n.t('geoman.tooltips.continueLine'),
      finishLine: I18n.t('geoman.tooltips.finishLine'),
      finishPoly: I18n.t('geoman.tooltips.finishPoly'),
      finishRect: I18n.t('geoman.tooltips.finishRect'),
      startCircle: I18n.t('geoman.tooltips.startCircle'),
      finishCircle: I18n.t('geoman.tooltips.finishCircle'),
      placeCircleMarker: I18n.t('geoman.tooltips.placeCircleMarker')
    },
    actions: {
      finish: I18n.t('geoman.actions.finish'),
      cancel: I18n.t('geoman.actions.cancel'),
      removeLastVertex: I18n.t('geoman.actions.removeLastVertex')
    },
    buttonTitles: {
      drawMarkerButton: I18n.t('geoman.buttonTitles.drawMarkerButton'),
      drawPolyButton: I18n.t('geoman.buttonTitles.drawPolyButton'),
      drawLineButton: I18n.t('geoman.buttonTitles.drawLineButton'),
      drawCircleButton: I18n.t('geoman.buttonTitles.drawCircleButton'),
      drawRectButton: I18n.t('geoman.buttonTitles.drawRectButton'),
      editButton: I18n.t('geoman.buttonTitles.editButton'),
      dragButton: I18n.t('geoman.buttonTitles.dragButton'),
      cutButton: I18n.t('geoman.buttonTitles.cutButton'),
      deleteButton: I18n.t('geoman.buttonTitles.deleteButton'),
      drawCircleMarkerButton: I18n.t('geoman.buttonTitles.drawCircleMarkerButton')
    }
  };
};
