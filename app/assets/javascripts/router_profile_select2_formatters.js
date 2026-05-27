// Shared Select2 templates for profile-grouped router selects (customer + reseller admin forms).

export function escapeCustomerRouterText(text) {
  return $('<span>').text(text || '').html();
}

function isResellerDefaultRouterOption(data) {
  if (!data || !data.id || !data.element) {
    return false;
  }
  return $(data.element).data('resellerDefault') === true;
}

function customerRouterOptionClass(data) {
  return isResellerDefaultRouterOption(data) ?
    'customer-router-option-label customer-router-option-label--default' :
    'customer-router-option-label';
}

export function formatCustomerRouterProfileResult(data) {
  if (data.children) {
    return $('<span class="customer-router-profile-label">' +
      '<i class="fa fa-layer-group fa-fw" aria-hidden="true"></i>' +
      escapeCustomerRouterText(data.text) +
      '</span>');
  }

  if (!data.id) {
    return data.text;
  }

  return $('<span class="' + customerRouterOptionClass(data) + '">' +
    '<i class="fa fa-route fa-fw" aria-hidden="true"></i>' +
    escapeCustomerRouterText(data.text) +
    '</span>');
}

export function formatCustomerRouterProfileSelection(data) {
  if (!data.id) {
    return data.text;
  }

  var $option = $(data.element);
  var profileName = $option.parent('optgroup').attr('label');
  var routerClass = isResellerDefaultRouterOption(data) ?
    'customer-router-selection-router customer-router-selection-router--default' :
    'customer-router-selection-router';

  if (!profileName) {
    return $('<span class="' + customerRouterOptionClass(data) + '">' +
      escapeCustomerRouterText(data.text) +
      '</span>');
  }

  return $('<span class="customer-router-selection">' +
    '<span class="customer-router-selection-profile">' + escapeCustomerRouterText(profileName) + '</span>' +
    '<span class="customer-router-selection-separator" aria-hidden="true">›</span>' +
    '<span class="' + routerClass + '">' + escapeCustomerRouterText(data.text) + '</span>' +
    '</span>');
}

export function formatCustomerRouterDimensionResult(data) {
  if (data.children) {
    return $('<span class="customer-router-dimension-label">' + escapeCustomerRouterText(data.text) + '</span>');
  }

  if (!data.id) {
    return data.text;
  }

  return $('<span class="' + customerRouterOptionClass(data) + '">' + escapeCustomerRouterText(data.text) + '</span>');
}
