module PlanningExport
  extend ActiveSupport::Concern

  def export_filename(planning, ref)
    array = []
    array << planning.name
    array << ref
    array << planning.order_array.name if planning.customer.enable_orders && planning.order_array
    array << I18n.l(planning.date) if planning.date
    array.join('_').tr('/', '-').delete('"')
  end

  def kmz_string_io(options = {})
    Zip::OutputStream.write_buffer do |zio|
      zio.put_next_entry(filename + '.kml')
      if options[:route]
        zio.write render_to_string(
          template: 'routes/show',
          formats: :kml,
          locals: options.slice(:route)
        )
      elsif options[:planning]
        zio.write render_to_string(
          template: 'plannings/show',
          formats: :kml,
          locals: options.slice(:planning)
        )
      end
      store_img_path = 'marker-home.png'
      zio.put_next_entry(store_img_path)
      zio.print IO.read('public/' + store_img_path)
      if options[:with_home_markers]
        (COLORS_TABLE + ['#000000']).each { |color|
          img_path = 'marker-home-' + color[1..-1] + '.png'
          zio.put_next_entry(img_path)
          zio.print IO.read('public/' + img_path)
        }
      end
      (COLORS_TABLE + ['#707070']).each { |color|
        img_path = 'point-' + color[1..-1] + '.png'
        zio.put_next_entry(img_path)
        zio.print IO.read('public/' + img_path)
      }
    end
  end
end
