# Copyright © Cartoway, 2026
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
module OmniauthHelper
  # Returns the logo image tag for a given OmniAuth provider
  # @param provider [Symbol] The provider name (e.g., :entra_id, :google_oauth2)
  # @param options [Hash] Options to pass to image_tag
  # @return [String] HTML image tag
  def omniauth_provider_logo(provider, options = {})
    default_options = { height: 20, style: 'vertical-align: middle; margin-right: 8px;' }
    options = default_options.merge(options)

    logo_path = provider_logo_path(provider)

    if logo_path
      image_tag(logo_path, options)
    else
      # Fallback to icon if no logo is available
      content_tag(:i, '', class: provider_icon_class(provider))
    end
  end

  # Returns the logo path for a given provider
  # @param provider [Symbol] The provider name
  # @return [String, nil] Path to the logo image or nil if not found
  def provider_logo_path(provider)
    logo_mapping = {
      entra_id: 'sso/microsoft.svg',
    }

    logo_file = logo_mapping[provider.to_sym]
    return nil unless logo_file

    # Check if file exists
    logo_path = Rails.root.join('app', 'assets', 'images', logo_file)
    File.exist?(logo_path) ? logo_file : nil
  end

  # Returns the icon class for a provider (fallback)
  # @param provider [Symbol] The provider name
  # @return [String] Font Awesome icon class
  def provider_icon_class(provider)
    icon_mapping = {
      entra_id: 'fa fa-windows'
    }

    icon_mapping[provider.to_sym] || 'fa fa-sign-in'
  end
end
