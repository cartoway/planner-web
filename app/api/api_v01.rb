# Copyright © Mapotempo, 2014-2015
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
class ApiV01 < Grape::API
  version '0.1', using: :path

  content_type :json, 'application/json; charset=UTF-8'
  content_type :geojson, 'application/vnd.geo+json; charset=UTF-8'
  content_type :xml, 'application/xml'

  # As rails utils 'status()' works with Integer, we need to set a special formatter for XML object
  xml_custom_formatter = ->(object, env) {
    object.is_a?(Integer) ? object.to_s : object.to_xml
  }

  formatter :xml, xml_custom_formatter

  default_format :json

  mount V01::Api

  add_swagger_documentation(
    base_path: '/api',
    hide_documentation_path: true,
    array_use_braces: true,
    consumes: [
      'application/json; charset=UTF-8',
      'application/xml'
    ],
    produces: [
      'application/json; charset=UTF-8',
      'application/vnd.geo+json; charset=UTF-8',
      'application/xml'
    ],
    doc_version: nil,
    security_definitions: {
      api_key_query_param: {
        type: 'apiKey',
        name: 'api_key',
        in: 'query'
      },
      api_key_header_param: {
        type: 'apiKey',
        name: 'Api-Key',
        in: 'header'
      },
    },
    security: [{
        api_key_query_param: [],
        api_key_header_param: []
    }],
    info: {
      title: 'API',
      contact_email: Planner::Application.config.api_contact_email,
      contact_url: Planner::Application.config.api_contact_url,
      license: 'GNU Affero General Public License 3',
      license_url: 'https://raw.githubusercontent.com/cartoway/planner-web/master/LICENSE',
      version: '0.1',
      description: '
[Getting started (happy path, pitfalls, workflows, curl)](' + Planner::Application.config.swagger_docs_base_path + '/api/0.1/getting-started.md).
[Simplified view of domain model](' + Planner::Application.config.swagger_docs_base_path + '/api/0.1/Model-simpel.svg).

## Model
Model is structured around four major concepts: the Customer account, Destinations/Visits, Vehicles and Plannings.
* `Customers`: many objects are linked to a customer account (relating to the user calling the API).
The customer has many `Users`, each user has his own `api_key`. Be careful not to confuse with the following model `Destination`. A `Customer` can only be created by an admin `User`.
* `Destinations` describe geographical points. `Visits` hold the actions to be performed and the associated constraints. Visits may be nested in the destination definition. The same `Destination` can be visited several times. A `Visit` might have multiple pickup and delivery quantities linked to a `DeliverableUnit`.
* `Vehicles` are split in two parts:
 * the structural definition named `Vehicle` (car, truck, bike, consumption, etc.)
 * the vehicle usage `VehicleUsage`, a specific usage of a physical vehicle in a context. Vehicles can be used in many contexts called `VehicleUsageSet`. Multiple sets are only available if the dedicated customer option is active. For instance, two sets "Morning" and "Evening" can each have different stores, rest, etc. `VehicleUsageSet` defines default values for vehicle usages.
* `Plannings`: a `Planning` is a set of `Routes` to `Visit` `Destinations` with `Vehicle` within a `VehicleUsageSet` context.
There is no create-stop or create-route endpoint. Creating a planning automatically creates one unassigned (out-of-route) route, one route per vehicle, and one stop per matching visit.

## Conventions
### Authentication
Send the user `api_key` as a query parameter **or** as header `Api-Key`:
`https://planner.cartoway.com/api/0.1/destinations.json?api_key={your_personal_api_key}`
`curl -H "Api-Key: {your_personal_api_key}" ...`
All data is scoped to the user\'s `Customer`. HTTP **402** means the subscription has expired. HTTP **403** means the action is forbidden.
### Identifiers
Path and filter ids accept a numeric id (`42`) or an external reference (`ref:CLIENT-12`). References must not contain commas. `ref` is the upsert key on destination/visit/store import.
### Formats
URL extension selects the response: `.json` (default), `.xml`, `.geojson` (destinations, visits, plannings, routes), `.ics` (plannings, routes).
There is no pagination: filter lists with `ids`, dates or tags.
### Times
Input schedule fields use `HH:MM` or `HH:MM:SS`. Output times are DateTime values, often based on the planning date.
### I18n
Functional messages and CSV headers follow `Accept-Language`. HTTP error codes are not translated. Errors look like `{ "message": "...", "status": 401 }`.
### Asynchronous jobs
Optimization and bulk geocoding return a `Job`. Poll `GET /jobs/:id`: HTTP **404** means success (the job is deleted); `failed_at` set means failure. HTTP **409** means another optimizer job is already running.

## Admin access
Using an admin `api_key` unlocks advanced operations (on `Customer`, `User`, `Vehicle`, `Profile`). Most operations from the current API are usable either for a normal user `api_key` or an admin user `api_key` (not both).
## More concepts
When a customer is created some objects are created by default:
* `Vehicle`: multiple, depending of the `max_vehicles` defined for customer
* `DeliverableUnit`: one default
* `VehicleUsageSet`: one default
* `VehicleUsage`: multiple, depending of the vehicles number
* `Store`: one default

### Profiles, Layers, Routers
`Profile` sets several parameters for the customer:
* `Layer`: background map
* `Router`: builds route geometry and travel times.

Several default profiles are available and can be listed with an admin `api_key`.

### Tags
`Tag` filters visits when creating a planning. For instance, visits tagged "Monday" can be used to create a planning that only includes those visits (`tag_operation`: `and` or `or`).
### Zonings
`Zoning` defines multiple `Zones` (areas). A `Zone` can be linked to a `Vehicle`. Applying the zoning on a `Planning` assigns destinations inside each area to that vehicle\'s route. Polygons can be provided or generated (clustering, isochrone, isodistance).

## Code samples
Workflows with curl: see [getting started](' + Planner::Application.config.swagger_docs_base_path + '/api/0.1/getting-started.md).
Runnable samples: [cURL](' + Planner::Application.config.swagger_docs_base_path + '/api/0.1/examples/curl/example.sh), [Python](' + Planner::Application.config.swagger_docs_base_path + '/api/0.1/examples/python/example.py), [PHP](' + Planner::Application.config.swagger_docs_base_path + '/api/0.1/examples/php/example.php), [Ruby](' + Planner::Application.config.swagger_docs_base_path + '/api/0.1/examples/ruby/example.rb).
You can import destinations/visits and create a planning at the same time if you already know the route for each visit (`importDestinations`). Creating a planning materializes routes and stops. Move stops between routes, or use zoning (automatic clustering) to assign many unassigned stops at once.
'})
end
