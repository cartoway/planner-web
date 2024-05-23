# Planner
Route optimization with numerous stops. Based on [OpenStreetMap](http://www.openstreetmap.org) and [OR-Tools](http://code.google.com).

## Installation

1. [Project dependencies](#project-dependencies)
2. [Install Bundler Gem](#install-bundler-gem)
3. [Install Node modules](#install-node-modules)
4. [Requirements for all systems](#requirements-for-all-systems)
5. [Install project](#install-project)
6. [Configuration](#configuration)
7. [Background Tasks](#background-tasks)
8. [Initialization](#Initialization)
9. [Running](#running)
10. [Running on producton](#running-on-production)
11. [Launch tests](#launch-tests)

### Project dependencies

#### On Ubuntu

Install Ruby (> 2.2 is needed) and other dependencies from system package.

For example, with __Ubuntu__, follows this instructions:

To know the last version, check with this command tools

    apt-cache search [package_name]

First, install Ruby:

    sudo apt install ruby2.3.7 ruby2.3.7-dev

Next, install Postgresql environement:

    sudo apt install postgresql postgresql-client-9.6 postgresql-server-dev-9.6

You need some others libs:

    sudo apt install libz-dev libicu-dev build-essential g++ libgeos-dev libgeos++-dev

__It's important to have all of this installed packages before installing following gems.__

#### On Fedora

Install ruby (>2.2 is needed), bundler and some dependencies from system package.

    yum install ruby ruby-devel rubygem-bundler postgresql-devel libgeos++-dev

#### On Mac OS

Install ruby (>2.2 is needed), bundler and some dependencies from system package.

    brew install postgresql icu4c geos

### Install Node modules

In addition to gems, node modules must be installed for Javascript files.
To install all dependencies, run the following command after installing yarn:

    yarn install

All packages will be available through _node_modules_ directory.

If a npm package includes assets, they must be declared in the _config/initializers/assets.rb_ file:

    Rails.application.config.assets.paths += Dir["#{Rails.root}/node_modules/package/asset_dir"]

## Configuration

### Background Tasks
Delayed job (background task) can be activated by setting `Mapotempo::Application.config.delayed_job_use = true` it's allow asynchronous running of import geocoder and optimization computation.

## Initialization

Check database configuration in `config/database.yml` and from project directory create a database for your environment with:

As postgres user:

    sudo -i -u postgres

Create user and databases:

    createuser -s [username]
    createdb -E UTF8 -T template0 -O [username] dev
    createdb -E UTF8 -T template0 -O [username] test

As normal user, we call rake to initialize databases (load schema and demo data):

    rake db:setup

### Override variables
Default project configuration is in `config/application.rb` you can override any setting by create a `config/initializers/your_config.rb` file and override any variable.

External resources can be configured trough environment variables:
* POSTGRES_USER, default: 'planner'
* POSTGRES_PASSWORD, default: 'planner'
* POSTGRES_DB', default: 'planner-test', 'planner-dev' or 'planner-prod'
* REDIS_HOST', default: 'localhost', production environment only
* OPTIMIZER_URL, default: 'http://localhost:1791/0.1'
* OPTIMIZER_API_KEY, default: 'demo'
* GEOCODER_URL, default: 'http://localhost:8558/0.1'
* GEOCODER_API_KEY, default: 'demo'
* ROUTER_URL, default: 'http://localhost:4899/0.1'
* ROUTER_API_KEY, default: 'demo'
* HERE_APP_ID
* HERE_APP_CODE
* DEVICE_TOMTOM_API_KEY
* DEVICE_FLEET_ADMIN_API_KEY

## Running

Start standalone rails server with:

    rails server

Start Webpack to auto-compile JS assets (and reload browser on change):

    ./bin/webpack-dev-server

Enjoy at [http://localhost:3000](http://localhost:3000)

To run both server in on command, you can launch Guard (configuration in _Guardfile_):

    guard

Start the background jobs runner with

    ./bin/delayed_job run

Or set the use of delayed job to false in your app config:

    Mapotempo::Application.config.delayed_job_use = false

## Running on production

Setup assets:

    rake i18n:js:export
    rake assets:precompile

## Launch tests

    rake test

If you focus one test only or for any other good reasons, you don't want to check i18n and coverage:

    rake test I18N=false COVERAGE=false

## Translation

Add new locale:
* Update `config/application.rb`
* Require the translation assets into `app/assets/javascripts/application.js`

# CI
Build is generated on each push to ce, beta or prod branch.
To be able to generate the image, add the following variable to your CI settings.

 - USER (registry user login name)
 - PASSWORD (registry user login password)
 - PRIVATE_TOKEN: user private token


# Docker
## Prerequisite

Install Docker Engine : [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)

## Building
```
docker compose build
```

## Settings
Copie and update settings.
```
cp .env.template .env
cp config/environments/production.rb docker/
```

For dev setup, enable the `docker-compose-dev.yml` by enabling it in .env file.
```yaml
COMPOSE_FILE=docker-compose.yml:docker-compose-dev.yml
```

## Run

```
docker compose up -d
```

## Initializing database

```
docker compose up -d
docker compose exec --user postgres db psql -c "CREATE ROLE planner PASSWORD 'planner' LOGIN;"
docker compose exec --user postgres db psql -c "CREATE DATABASE planner OWNER planner ENCODING 'utf-8';"
docker compose exec --user postgres db psql planner -c "CREATE EXTENSION hstore;"
docker compose run --rm web bundle exec rake db:setup
```

Update the database schema after version update with
```
docker compose run --rm web bundle exec rake db:migrate
```

## Dev in Docker

For dev in docker add `SUPERUSER`.
```
# docker compose exec --user postgres db psql -c "ALTER USER planner WITH SUPERUSER;"
```

To reset the instance
```
docker compose down
docker compose up -d db
docker compose exec --user postgres db psql -c "DROP DATABASE planner;"
docker compose exec --user postgres db psql -c "DROP ROLE planner;"
```

Update the `db/structure.sql` file
```
docker compose run --rm web bundle exec rake db:structure:dump
```

## Dev in Docker through VSCode

* Install [Visual Studio Code](https://code.visualstudio.com/download)
* Install the following extensions : Docker & Dev Containers
* Press F1 > Select command "Dev Containers: Open Folder in Container..."
* Select this repository
* You should now be able to edit, commit and push from the container

## Tests in Docker

Prepare for tests:
```
docker compose exec --user postgres db psql -c "CREATE DATABASE test OWNER planner;"
RAILS_ENV=test docker compose run --rm web bundle exec rake i18n:js:export
RAILS_ENV=test docker compose run --rm web bundle exec rake assets:precompile
```

Run tests:
```
RAILS_ENV=test docker compose run --rm web rake test I18N=false COVERAGE=false
```

## Analytics

Analytics can be enabled by adding `docker-compose-superset.yml` to the `COMPOSE_FILE` variable into `.env` file.

Analytics should be initialized with
```
docker compose exec --user postgres db psql -c "CREATE DATABASE superset;"
docker compose run --rm superset bash -c "
    superset db upgrade
    superset fab create-admin \
        --username admin \
        --firstname Superset \
        --lastname Admin \
        --email admin@superset.com \
        --password admin
    superset init
    superset fab import-roles -p superset-public-permissions.json
    "
```

Then go to Superset at localhost:8089 and setup dashboard.

Add cron every hour to historyze relevant data
```
0 * * * * cd planner-web && docker compose run --rm web bundle exec rake db:history:historize
```

## Documentation
The Web API, providing views, is statically generated while rake precompile the project.
The REST API is, on its side, dynamically generated.
