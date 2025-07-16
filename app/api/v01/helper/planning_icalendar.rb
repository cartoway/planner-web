module PlanningIcalendar
  require 'icalendar/tzinfo'

  def planning_date(route)
    # Time.zone is settled in Api root folder
    route.planning.date ? Time.zone.parse(route.planning.date.to_s) : Time.zone.now.beginning_of_day
  end

  def p_time(route, time)
    planning_date(route) + time
  end

  def stop_ics(route, stop, event_start)
    event = Icalendar::Event.new
    event.uid = [stop.id, stop.visit_id].join('-')
    event.dtstart = event_start
    event.dtend = event_start + stop.duration.to_i # Exclusive xor with event.duration
    event.summary = stop.name
    event.location = [stop.street, stop.detail, stop.postalcode, stop.city, stop.country].reject(&:blank?).join(', ')
    event.categories = route.ref || route.vehicle_usage.vehicle.name.delete(',')
    event.description = [stop.phone_number, stop.comment].reject(&:blank?).join("\n")
    event.created = stop.created_at
    event.last_modified = stop.updated_at
    event.organizer = Icalendar::Values::CalAddress.new("mailto:#{@current_user.email}", cn: @current_user.customer.name)
    if stop.phone_number
      event.attendee = Icalendar::Values::CalAddress.new("tel:#{stop.phone_number}", cn: stop.phone_number)
    end
    # event.duration not supported in S Planner
    event.geo = [stop.lat, stop.lng]
    event
  end

  def add_route_to_calendar(calendar, route)
    route.stops.select(&:active?).select(&:position?).select(&:time?).sort_by(&:index).each do |stop|
      event_start = p_time(route, stop.time)

      calendar.add_event stop_ics(route, stop, event_start)
    end
  end

  def planning_calendar(planning)
    calendar = Icalendar::Calendar.new
    create_timezone calendar
    Route.includes_destinations_and_stores.scoping do
      planning.routes.select(&:vehicle_usage_id).each do |route|
        add_route_to_calendar calendar, route
      end
    end
    calendar
  end

  def plannings_calendar(plannings)
    calendar = Icalendar::Calendar.new
    Route.includes_destinations_and_stores.scoping do
      plannings.each do |planning|
        create_timezone calendar
        planning.routes.select(&:vehicle_usage_id).each do |route|
          add_route_to_calendar calendar, route
        end
      end
    end
    calendar
  end

  def route_calendar(route)
    calendar = Icalendar::Calendar.new
    create_timezone calendar
    add_route_to_calendar calendar, route
    calendar
  end

  def route_calendar_email(routes_to_send)
    routes_to_send.each do |email, infos|
      if Planner::Application.config.delayed_job_use
        RouteMailer.delay.send_computed_ics_route(@current_user, I18n.locale, email, infos)
      else
        RouteMailer.send_computed_ics_route(@current_user, I18n.locale, email, infos).deliver_now
      end
    end
  end

  def create_timezone(calendar)
    tz = TZInfo::Timezone.get(Time.zone.tzinfo.name).ical_timezone(Time.zone.now)

    calendar.add_timezone tz unless timezone_exist?(calendar, tz)
  end

  def timezone_exist?(calendar, tz)
    calendar.timezones.any? { |t| t.tzid == tz.tzid }
  end
end
