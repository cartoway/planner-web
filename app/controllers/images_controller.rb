# Copyright © Mapotempo, 2013-2014
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
require 'color'

class ImagesController < ApplicationController
  def marker
    @pal = pal(image_params[:color])
  end

  def marker_home
    @color = image_params[:color]
  end

  def point
    @pal = pal(image_params[:color])
  end

  def square
    @pal = pal(image_params[:color])
  end

  def diamon
    @pal = pal(image_params[:color])
  end

  def star
    @pal = pal(image_params[:color])
  end

  def user
    @pal = pal(image_params[:color])
  end

  def point_large
    @pal = pal(image_params[:color])
  end

  private

  def range(x)
    x.clamp(0, 1)
  end

  def pal(hex)
    begin
      rgb = Color::RGB.by_hex(hex)
    rescue
      rgb = Color::RGB.by_hex('2d86cb')
    end
    hsl = rgb.to_hsl

    a_up = hsl.dup
    a_up.h = (a_up.h + 0.002) % 1
    a_up.s = range(a_up.s + 0.121)
    a_up.l = range(a_up.l - 0.066)

    a_down = hsl.dup
    a_down.h = (a_down.h - 0.002) % 1
    a_down.s = range(a_down.s - 0.121)
    a_down.l = range(a_down.l + 0.066)

    b_up = hsl.dup
    b_up.s = range(b_up.s - 0.102)

    b_down = hsl.dup
    b_down.s = range(b_down.s - 0.102)
    b_down.l = range(b_down.l - 0.142)

    [['#' + a_up.to_rgb.hex, '#' + a_down.to_rgb.hex], ['#' + b_up.to_rgb.hex, '#' + b_down.to_rgb.hex]]
  end

  def image_params
    params.permit(:color)
  end
end
