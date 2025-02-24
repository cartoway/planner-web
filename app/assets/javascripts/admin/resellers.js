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
function admin_resellers_form(params, api) {
  $(":file").filestyle({
    buttonName: "btn-primary",
    iconName: "fa fa-folder-open",
    buttonText: I18n.t('web.choose_file')
  });

  $('input[name="reseller[messagings][active_service]"]').on('change', function() {
    $('.messaging-fields').addClass('d-none');

    if (this.checked) {
      $('.messaging-fields[data-service="' + this.value + '"]').removeClass('d-none');
    }
  });
}


function admin_resellers_edit(params, api) {
  admin_resellers_form(params, api);
}

Paloma.controller('Admin/Resellers', {
  edit: function() {
    admin_resellers_edit(this.params);
  }
});

Paloma.controller('Admin/Resellers', {
  update: function() {
    admin_resellers_edit(this.params);
  }
});
