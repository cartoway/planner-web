# Changelog

## V103.0.1-dev
  ### Added
  - API:
    - Allow commas for float fields [#205](https://github.com/cartoway/planner-web/pull/205)
    - Capture sentry from API [#209](https://github.com/cartoway/planner-web/pull/209)
  - Planning: Add router name to vehicle selector [#202](https://github.com/cartoway/planner-web/pull/202)
  - Destination: Allow commas for float columns during import [#203](https://github.com/cartoway/planner-web/pull/203) & [#208](https://github.com/cartoway/planner-web/pull/208)
  - Device: Set a 2s timeout for StgTelematics[#209](https://github.com/cartoway/planner-web/pull/209)
  - Zoning:
    - Simplify polygons geometries [#207](https://github.com/cartoway/planner-web/pull/207)
    - Destroy unconsistent polygons [#210](https://github.com/cartoway/planner-web/pull/210)

  ### Changed
  - Allow rails to use fallback in case of missing assets [#196](https://github.com/cartoway/planner-web/pull/196)
  - Rails 6 shares callbacks across threads [#197](https://github.com/cartoway/planner-web/pull/197)
  - Setup cookies with same site policy [#201](https://github.com/cartoway/planner-web/pull/201)
  - Set max zoom to 19 [#204](https://github.com/cartoway/planner-web/pull/204)
  - Planning: stop counter now uses a cache [#207](https://github.com/cartoway/planner-web/pull/207)
  - Store: use `find_in_batches` within geocoder job [#205](https://github.com/cartoway/planner-web/pull/205)
  - Zoning:
    - Improve loading performances [#199](https://github.com/cartoway/planner-web/pull/199)
    - Increase zone border weight & Change edit marker style [#207](https://github.com/cartoway/planner-web/pull/207)

  ### Removed

  ### Fixed
  - Api-web:  Remove blank header bar [#201](https://github.com/cartoway/planner-web/pull/201)
  - Route: Avoid unexpected stops reloading during creation [#200](https://github.com/cartoway/planner-web/pull/200)
  - Destination
    - Import: New quantities columns are immediatly usable [#203](https://github.com/cartoway/planner-web/pull/203)
    - Import: Cumulative lines with tags were failing [#203](https://github.com/cartoway/planner-web/pull/203) & [#208](https://github.com/cartoway/planner-web/pull/208)
    - Controller: edit params indirectly [#205](https://github.com/cartoway/planner-web/pull/205)
  - Planning: Selectors are no more resizing on click [#202](https://github.com/cartoway/planner-web/pull/202)
  - Vehicle Usage: _form was unrechable with an active device [#205](https://github.com/cartoway/planner-web/pull/205)

