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
// Turbolinks hack to display notify on previous page
// $(document).on('page:restore', function () {
//   PNotify.prototype.options.stack.context = $('body');
// });

PNotify.prototype.options.styling = 'fontawesome';

PNotify.prototype.options.buttons.labels = {
  close: I18n.t('web.dialog.close')
};

var stack_bottomright = {"dir1": "up", "dir2": "left", "firstpos1": 35, "firstpos2": 35};

const isWindowVisible = (function() {
  var stateKey, eventKey, keys = {
    hidden: 'visibilitychange',
    webkitHidden: 'webkitvisibilitychange',
    mozHidden: 'mozvisibilitychange',
    msHidden: 'msvisibilitychange'
  };
  for (stateKey in keys) {
    if (stateKey in document) {
      eventKey = keys[stateKey];
      break;
    }
  }
  return function(callback) {
    if (callback) document.addEventListener(eventKey, callback);
    return !document[stateKey];
  };
})();

(function() {
  'use strict';

  function notify(status, message, options) {
    var notification = function() {
      new PNotify($.extend({
        text: message,
        type: status,
        animation: 'slide',
        animate_speed: 'slow',
        shadow: true,
        hide: true,
        stack: stack_bottomright,
        buttons: {
          sticker: false,
          closer: true
        }
      }, options));
    };

    var notifyDisplayed = false;
    if (isWindowVisible()) {
      notification();
    } else {
      isWindowVisible(function() {
        if (isWindowVisible()) {
          if (!notifyDisplayed) {
            notification();
          }
          notifyDisplayed = true;
        }
      });
    }
  }

  // function desktop_notify(status, message, options) {
  //   PNotify.desktop.permission();
  //   notify(status, message, $.extend({
  //     title: resellerName,
  //     desktop: {
  //       desktop: true
  //     }
  //   }, options));
  // }

  $.extend(window, {
    notify: function(status, message, options) {
      notify(status, message, $.extend({}, options));
    },
    notice: function(message, options) {
      notify('success', message, options);
    },
    stickyNotice: function(message, options) {
      notify('success', message, $.extend(options, {
        hide: false
      }));
    },
    warning: function(message, options) {
      notify('warning', message, options);
    },
    error: function(message, options) {
      notify('error', message, options);
    },
    stickyError: function(message, options) {
      notify('error', message, $.extend(options, {
        hide: false
      }));
    },
    hideNotices: function() {
      PNotify.removeAll();
    }
  });
})();
