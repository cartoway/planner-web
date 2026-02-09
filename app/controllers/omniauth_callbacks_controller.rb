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
class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def entra_id
    auth = request.env['omniauth.auth']

    # If user is signed in, link the account
    if user_signed_in?
      link_account(auth)
    else
      # Try to find user by identity or email
      identity = Identity.find_by(provider: auth.provider, uid: auth.uid)

      if identity
        # User exists, sign them in
        sign_in_and_redirect identity.user, event: :authentication
        set_flash_message(:notice, :success, kind: t('all.providers.' + auth.provider)) if is_navigational_format?
      else
        # Try to find user by email
        user = User.find_by(email: auth.info.email)

        if user
          # Link the account to existing user
          user.identities.create!(provider: auth.provider, uid: auth.uid)
          sign_in_and_redirect user, event: :authentication
          set_flash_message(:notice, :success, kind: t('all.providers.' + auth.provider)) if is_navigational_format?
        else
          # New user - redirect to registration or show error
          session['devise.entra_id_data'] = auth
          redirect_to new_user_registration_path, alert: t('devise.omniauth_callbacks.no_account', provider: auth.provider)
        end
      end
    end
  end

  def failure
    redirect_to root_path, alert: t('devise.omniauth_callbacks.failure', kind: auth.provider, reason: failure_message)
  end

  private

  def link_account(auth)
    # Check if this SSO account is already linked to another user
    existing_identity = Identity.find_by(provider: auth.provider, uid: auth.uid)

    if existing_identity && existing_identity.user != current_user
      redirect_to edit_user_path(current_user), alert: t('devise.omniauth_callbacks.already_linked', provider: t('all.providers.' + auth.provider))
      return
    end

    identity = current_user.identities.find_or_initialize_by(provider: auth.provider, uid: auth.uid)

    if identity.save
      redirect_to edit_user_path(current_user), notice: t('devise.omniauth_callbacks.account_linked', provider: t('all.providers.' + auth.provider))
    else
      redirect_to edit_user_path(current_user), alert: t('devise.omniauth_callbacks.link_failed', provider: t('all.providers.' + auth.provider))
    end
  end
end
