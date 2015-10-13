Mapotempo-Web Plugin by time/distance
=======================================
Add api-web and api end-point to show the closest stores to [Mapotempo-web](https://github.com/Mapotempo/mapotempo-web).

Add routes:
```
get /api-web/0.1/stores/by_distance
get /api/0.1/stores_by_distance.{format}
```

Installation
============

Add this line to your application's Gemfile:

    gem 'mapotempo_web_by_time_distance', path: '../mapotempo_web_by_time_distance'

And then execute:

    $ bundle

Usage
=====

Add the following JavaScript file to `app/assets/javascripts/application.js`:

    //= require mapotempo_web_by_time_distance

License
=======

Mapotempo is licensed under the AGPL-3 license, this gem too.
