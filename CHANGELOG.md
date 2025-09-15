# Changelog

## Dev
  ### Added
  - Customer: Allow to order and filter the solvers to use [#422](https://github.com/cartoway/planner-web/pull/422)
  - Planning: Introduce a lasso to select multiple stops on the fly [#424](https://github.com/cartoway/planner-web/pull/424)
  - OptimizerJob
    - Stores the solver used and the ones skipped (with reasons) on the job info [#422](https://github.com/cartoway/planner-web/pull/422)
    - Stores problem details [#470](https://github.com/cartoway/planner-web/pull/470)
  - Introduce a short delay before SimplifyGeojsonTracksJob [#447](https://github.com/cartoway/planner-web/pull/447)
  - Connect pickup and deliveries quantities to equivalent feature in Optimizer-API [#453](https://github.com/cartoway/planner-web/pull/453)

  ### Changed
  - Export: Rework visually the columns selector [#422](https://github.com/cartoway/planner-web/pull/422)
  - Rework of the automatic insert method [#423](https://github.com/cartoway/planner-web/pull/423)
  - Bump turbolinks [#431](https://github.com/cartoway/planner-web/pull/431)
  - Bump rails_performance from 1.4.1 to 1.5.1 to fix a memory leak [#460](https://github.com/cartoway/planner-web/pull/460)
  - Bump leaflet from 1.0.3 et 1.9.1 and bump dependencies [#450](https://github.com/cartoway/planner-web/pull/450)
  - Routes:
    - Add stores to scopes [#435](https://github.com/cartoway/planner-web/pull/435)
    - Ensure compute_saved! is in a transaction [#435](https://github.com/cartoway/planner-web/pull/435)
  - Update rubocop rules [#440](https://github.com/cartoway/planner-web/pull/440)
  - Use activerecord-import for Planning#create [#444](https://github.com/cartoway/planner-web/pull/444)
  - Move stop and lasso now use a common modal feature [#455](https://github.com/cartoway/planner-web/pull/455) & [#461](https://github.com/cartoway/planner-web/pull/461)
  - Update the default favicon [#467](https://github.com/cartoway/planner-web/pull/467)
  - Introduce `DecimalAttr` on revenue to limit the number of decimals [#475](https://github.com/cartoway/planner-web/pull/475)
  - Introduce Geoman to handle zoning & introduce snapping [#450](https://github.com/cartoway/planner-web/pull/450)

  ### Removed
  - Remove Iconv from dependencies [#457](https://github.com/cartoway/planner-web/pull/457)
  - Remove Leaflet.Draw from dependencies [#450](https://github.com/cartoway/planner-web/pull/450)

  ### Fixed
  - StopStore
    - create and destroy [#464](https://github.com/cartoway/planner-web/pull/464)
    - Planning import was ignoring multiple references to a single Store [#473](https://github.com/cartoway/planner-web/pull/473)
  - Zone destroy [#467](https://github.com/cartoway/planner-web/pull/467)
  - Display tag field on destination and visit forms even if none is existing [#476](https://github.com/cartoway/planner-web/pull/476)
  - Export `destination.duration` in routes csv [#477](https://github.com/cartoway/planner-web/pull/477)
  - alerts on `tags` and `deliverable_units` [#478](https://github.com/cartoway/planner-web/pull/478) & [#479](https://github.com/cartoway/planner-web/pull/479) & [#481](https://github.com/cartoway/planner-web/pull/481)
  - Optimizer skills collect [#480](https://github.com/cartoway/planner-web/pull/480)
  - Avoid context reload during `move_stop` [#482](https://github.com/cartoway/planner-web/pull/482)

## V106.0.0
  ### Added
  - Destinations: Add a duration by destination [#361](https://github.com/cartoway/planner-web/pull/361)
  - Visits
    - Custom attributes are available in forms and displayed in plan stop pop-over [#338](https://github.com/cartoway/planner-web/pull/338)
  - Customers: Admin have access to the `cost_fixed` transmitted during route optimization [#374](https://github.com/cartoway/planner-web/pull/374)
  - Planning:
    - Routes: Allows to force the start time [#370](https://github.com/cartoway/planner-web/pull/370)
    - Stops:
      - Display the current load at each route step [#387](https://github.com/cartoway/planner-web/pull/387)
      - Add an alert for unfulfilled tag skills [#419](https://github.com/cartoway/planner-web/pull/419)
  - API V100 - Expose Stops custom_attributes [#443](https://github.com/cartoway/planner-web/pull/443)
  - Introduce StopStore : it materializes a stop performed at a store during a route [#418](https://github.com/cartoway/planner-web/pull/418)

  ### Changed
  - Bump `babel` to 7.23.2 [#330](https://github.com/cartoway/planner-web/pull/330)
  - Hide irrelevant logs in `rails_performance` [#331](https://github.com/cartoway/planner-web/pull/331)
  - Plannings: disable refresh button during compute [#378](https://github.com/cartoway/planner-web/pull/378)
  - Reseller: Invalidate reseller cache on change [#371](https://github.com/cartoway/planner-web/pull/371)
  - Route optimization:
    - service time is now considered in working shift [#335](https://github.com/cartoway/planner-web/pull/335)
    - Max delay is now always displayed in the modal [#388](https://github.com/cartoway/planner-web/pull/388)
  - Routes: Improve compute performances [#345](https://github.com/cartoway/planner-web/pull/345)
  - Grape API: Response logging disabled [#381](https://github.com/cartoway/planner-web/pull/381)
  - Destinations:
    - Set stops as outdated on coordinates change [#390](https://github.com/cartoway/planner-web/pull/390)
    - Improve performance of API destination delete endpoint [#446](https://github.com/cartoway/planner-web/pull/446)
  - Customers: Cache `destinations`, `plannings`, `vehicles` and `visits` count [#391](https://github.com/cartoway/planner-web/pull/391)
  - Change quantity representation from a single value into two value the quantity collected (pickups) and the quantity delivered (deliveries) [#408](https://github.com/cartoway/planner-web/pull/408)

  ### Removed
  - The option `enable_multi_visits` is removed, having multi visits is standard. Letting access to both destination and visit references simultaneously [#375](https://github.com/cartoway/planner-web/pull/375)

  ### Fixed
  - Fix menu accordion ovelapping [#369](https://github.com/cartoway/planner-web/pull/369)
  - Device services now returns a http code 408 when anavailable [#370](https://github.com/cartoway/planner-web/pull/370)
  - Route color reset correctly update stop popup "send_to_route" color [#381](https://github.com/cartoway/planner-web/pull/381)
  - Customers: Validates name length [#384](https://github.com/cartoway/planner-web/pull/384)
  - Plannings: Reintroduce Stops visit index [#386](https://github.com/cartoway/planner-web/pull/386)
  - Fix vehicle url on welcome page [#389](https://github.com/cartoway/planner-web/pull/389)

## V105.0.0
  ### Added
  - Mobile
    - Introduce asynchronous status update when offline [#272](https://github.com/cartoway/planner-web/pull/272) & [#274](https://github.com/cartoway/planner-web/pull/274) & [#275](https://github.com/cartoway/planner-web/pull/275)
    - Allow to send stops to another route [#274](https://github.com/cartoway/planner-web/pull/274)
    - Shorten URL to acess routes [#280](https://github.com/cartoway/planner-web/pull/280) & [#288](https://github.com/cartoway/planner-web/pull/288)
  - Planning
    - Display route costs and revenue [#264](https://github.com/cartoway/planner-web/pull/264) & [#270](https://github.com/cartoway/planner-web/pull/270)
    - Add the possibility to send the route to drivers using an SMS [#269](https://github.com/cartoway/planner-web/pull/269)
  - Reseller
    - Introduce SMS Partner as SMS provider [#283](https://github.com/cartoway/planner-web/pull/283)
    - Allow to switch between SMS providers [#283](https://github.com/cartoway/planner-web/pull/283)
  - Zoning
    - Activate geocoding search [#250](https://github.com/cartoway/planner-web/pull/250)
    - Add color selector [#255](https://github.com/cartoway/planner-web/pull/255) & [#263](https://github.com/cartoway/planner-web/pull/263)
    - Center the view on a zone [#253](https://github.com/cartoway/planner-web/pull/253) & [#257](https://github.com/cartoway/planner-web/pull/257)
  - Vehicles
    - Add default fuel type and fuel consumption [#262](https://github.com/cartoway/planner-web/pull/262)
  - Allow max delay for optimization [#281](https://github.com/cartoway/planner-web/pull/281)
  - Welcome page now contains a summary of the customer data [#306](https://github.com/cartoway/planner-web/pull/306) & [#311](https://github.com/cartoway/planner-web/pull/311) & [#312](https://github.com/cartoway/planner-web/pull/312)

  ### Changed
  - Planning: Duplication adds current DateTime to the reference [#301](https://github.com/cartoway/planner-web/pull/301)
  - Route: Reduce db usage & improve Douglas Peucker algorithm performances during compute [#290](https://github.com/cartoway/planner-web/pull/290)
  - Space route name in route filter selector [#251](https://github.com/cartoway/planner-web/pull/251)
  - Update logo [#265](https://github.com/cartoway/planner-web/pull/265)
  - Update API documentation [#266](https://github.com/cartoway/planner-web/pull/266)
  - Balance default optimization costs [#267](https://github.com/cartoway/planner-web/pull/267) & [#284]((https://github.com/cartoway/planner-web/pull/284))
  - Unbranding [#261](https://github.com/cartoway/planner-web/pull/261) & [#272](https://github.com/cartoway/planner-web/pull/272)
  - Automatically launch db setup or migrate on docker service startup [#295](https://github.com/cartoway/planner-web/pull/295)
  - Update user's export preferences from localStorage to db storage [#292](https://github.com/cartoway/planner-web/pull/292)
  - Customer validations use `.count` instead of `.length` to reduce computation time [#319](https://github.com/cartoway/planner-web/pull/319)
  - `candidate_insert` now preloads data before route method `compute`

  ### Fixed
  - Fix how empty lines are skip from CSV on import [#252](https://github.com/cartoway/planner-web/pull/252)
  - Permute the order of inputs for vehicle usage form (option toll and option low emission) [#256](https://github.com/cartoway/planner-web/pull/256)
  - Map on route print now displays correctly [#259](https://github.com/cartoway/planner-web/pull/259)
  - Zones
    - Correctly count elements during creation and edition [#268](https://github.com/cartoway/planner-web/pull/268) & [#282](https://github.com/cartoway/planner-web/pull/282)
    - Generate zones from a planning was missing deliverable units [#300](https://github.com/cartoway/planner-web/pull/300)
  - Clear logs in test environment [#272](https://github.com/cartoway/planner-web/pull/272)
  - Help center link now displays correctly [#296](https://github.com/cartoway/planner-web/pull/296)
  - Destination and Visit
    - tags were duplicated on import update [#305](https://github.com/cartoway/planner-web/pull/305)
    - API documentation now correctly displays the two alternative to import tags. Directly with a list of ids (through `tag_ids`) or with a list of strings (through `tags`) [#337](https://github.com/cartoway/planner-web/pull/337)
  - Api-Web Planning callback button were breaking the panel structure [#305](https://github.com/cartoway/planner-web/pull/305)
  - Customer duplication now correctly transfer custom quantity related import headers [#323](https://github.com/cartoway/planner-web/pull/323)

  ### Removed
  - Customer parameters `optimization_stop_soft_upper_bound` and `optimization_vehicle_soft_upper_bound` are replaced by the combination of `enable_optimization_soft_upper_bound` with respectively `stop_max_upper_bound` and `vehicle_max_upper_bound` [#336](https://github.com/cartoway/planner-web/pull/336)

## V104.2.0
  ### Changed
  - Destination
    - Import: The route and vehicle columns should be consistent, otherwise an error is raised [#242](https://github.com/cartoway/planner-web/pull/242)
    - Import: Allows to update a single route in a pre-existing plan [#242](https://github.com/cartoway/planner-web/pull/242)
  ### Fixed
  - Planning: `candidate_insert` was failing if no route is available [#246](https://github.com/cartoway/planner-web/pull/246)

## V104.1.0
  ### Added
  - API: Add option `exclusion' to filter routes applied on Destination candidate_insert [#228](https://github.com/cartoway/planner-web/pull/228)
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

