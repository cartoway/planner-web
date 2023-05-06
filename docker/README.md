# Using Docker Compose

## Building

```
cd docker
docker-compose build
```

## Run

Copie `.env.template` as `.env` and update settings.

``
docker-compose up -d
```

## Initializing database

```
docker-compose exec --user postgres db psql -c "CREATE EXTENSION hstore;"
docker-compose run --rm web bundle exec rake db:setup
```
