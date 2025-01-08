# Changelog

## Dev
  ### Added
    - Add geocoder on zonning map

## V104.2.0
  ### Changed
    - Destination
      - Import: The route and vehicle columns should be consistent, otherwise an error is raised [#242](https://github.com/cartoway/planner-web/pull/242)
      - Import: Allows to update a single route in a pre-existing plan [#242](https://github.com/cartoway/planner-web/pull/242)
  ### Fixed
   - Planning: `candidate_insert` was failing if no route is available [#246](https://github.com/cartoway/planner-web/pull/246)

## V104.1.0
  ### Added
    - API: Add option `exclusion` to filter routes applied on Destination candidate_insert [#228](https://github.com/cartoway/planner-web/pull/228)
    - Destination: Validate ref uniqueness from API endpoints, nested visits are validated too [#211](https://github.com/cartoway/planner-web/pull/211)
    - Misc: Add `rails_performance` gem to monitor performances [#227](https://github.com/cartoway/planner-web/pull/227)

  ### Removed
  - `skip_callback` was not thread safe [#214](https://github.com/cartoway/planner-web/pull/214)

## V104.0.0
  ### Added
  - API:
    - Allow commas for float fields [#205](https://github.com/cartoway/planner-web/pull/205)
    - Capture sentry from API [#209](https://github.com/cartoway/planner-web/pull/209)
  - Planning:
    - Add router name to vehicle selector [#202](https://github.com/cartoway/planner-web/pull/202)
    - Display unassigned using a continuous loading on scroll method using Pagy [#217](https://github.com/cartoway/planner-web/pull/217)
    - Introduce the route selector [#217](https://github.com/cartoway/planner-web/pull/217)
    - Allow to hide route polylines [#217](https://github.com/cartoway/planner-web/pull/217)
    - Center the view on a route [#217](https://github.com/cartoway/planner-web/pull/217)
  - Destination: Allow commas for float columns during import [#203](https://github.com/cartoway/planner-web/pull/203) & [#208](https://github.com/cartoway/planner-web/pull/208)
  - Device: Set a 2s timeout for StgTelematics[#209](https://github.com/cartoway/planner-web/pull/209)
  - Zoning:
    - Simplify polygons geometries [#207](https://github.com/cartoway/planner-web/pull/207)
    - Destroy unconsistent polygons [#210](https://github.com/cartoway/planner-web/pull/210)
    - Confirmation on zone delete [#217](https://github.com/cartoway/planner-web/pull/217)

  ### Changed
  - Allow rails to use fallback in case of missing assets [#196](https://github.com/cartoway/planner-web/pull/196)
  - Rails 6 shares callbacks across threads [#197](https://github.com/cartoway/planner-web/pull/197)
  - Setup cookies with same site policy [#201](https://github.com/cartoway/planner-web/pull/201)
  - Set max zoom to 19 [#204](https://github.com/cartoway/planner-web/pull/204)
  - Bump Ruby version to 3.1.4 [#217](https://github.com/cartoway/planner-web/pull/217)
  - Touch routes and plannings while updating routes to reset cache (with some exceptions) [#217](https://github.com/cartoway/planner-web/pull/217)
  - Bump select2 version to 4.0.13
  - Planning:
   - Stop counter now uses a cache [#207](https://github.com/cartoway/planner-web/pull/207)
   - Use erb and haml view files instead of Mustache templates for main planning components [#217](https://github.com/cartoway/planner-web/pull/217)
   - Load and update the planning by fragment using .js.erb [#217](https://github.com/cartoway/planner-web/pull/217)
   - Freeze modified and loading routes [#217](https://github.com/cartoway/planner-web/pull/217)
   - set_stops now requires a hash {route_id: [stops_ids]} to be applied [#221](https://github.com/cartoway/planner-web/pull/221)
  - Store: use `find_in_batches` within geocoder job [#205](https://github.com/cartoway/planner-web/pull/205)
  - Zoning:
    - Improve loading performances [#199](https://github.com/cartoway/planner-web/pull/199)
    - Increase zone border weight & Change edit marker style [#207](https://github.com/cartoway/planner-web/pull/207)
    - Load using id order by default [#217](https://github.com/cartoway/planner-web/pull/217)

  ### Fixed
  - Api-web:  Remove blank header bar [#201](https://github.com/cartoway/planner-web/pull/201)
  - Route: Avoid unexpected stops reloading during creation [#200](https://github.com/cartoway/planner-web/pull/200)
  - Destination
    - Import: New quantities columns are immediatly usable [#203](https://github.com/cartoway/planner-web/pull/203)
    - Import: Cumulative lines with tags were failing [#203](https://github.com/cartoway/planner-web/pull/203) & [#208](https://github.com/cartoway/planner-web/pull/208)
    - Controller: edit params indirectly [#205](https://github.com/cartoway/planner-web/pull/205)
  - Planning: Selectors are no more resizing on click [#202](https://github.com/cartoway/planner-web/pull/202)
  - RoutesLayers: fix `with_geojson` option [#217](https://github.com/cartoway/planner-web/pull/217)
  - Vehicle Usage: _form was unrechable with an active device [#205](https://github.com/cartoway/planner-web/pull/205)

