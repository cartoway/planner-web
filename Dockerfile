# syntax=docker/dockerfile:1

ARG RUBY_IMAGE=3.1.7-alpine

# Step 1: Build (assets, gems, node_modules)
FROM ruby:${RUBY_IMAGE} AS builder
ENV NODE_OPTIONS=--openssl-legacy-provider \
    RAILS_ENV=production \
    NODE_ENV=production \
    YARN_PRODUCTION=false \
    SKIP_JS_COMPRESSOR=1 \
    BUNDLE_WITHOUT="development:test" \
    API_DOC_MODE=true

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    geos-dev \
    git \
    icu-dev \
    jemalloc-dev \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    nodejs \
    postgresql-dev \
    tzdata \
    yarn \
    zlib-dev

WORKDIR /srv/app

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/usr/local/bundle/cache \
    bundle config set --local no-doc 'true' && \
    bundle install --jobs=4 --retry=3

COPY package.json yarn.lock ./
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \
    YARN_PRODUCTION=false yarn install --frozen-lockfile

# Rails boot + i18n + Webpacker (no spec/: swagger not needed yet).
COPY Rakefile config.ru ./
COPY .babelrc .postcssrc.yml ./
COPY config/ config/
COPY bin/ bin/
COPY lib/ lib/
COPY vendor/ vendor/
COPY app/ app/
COPY public/ public/

RUN bundle exec rake i18n:js:export

# Webpack is the slowest step; keep it separate from sprockets and swagger generation.
RUN bundle exec rails webpacker:compile

# rswag:specs:swaggerize (hooked to assets:precompile) reads spec/ only.
COPY spec/ spec/

RUN bundle exec rake assets:precompile

# Runtime source not required to compile assets (keeps db/script changes off webpack layers).
COPY db/ db/
COPY script/ script/
COPY scripts/ scripts/

# Step 2: Final image, minimal
FROM ruby:${RUBY_IMAGE}

ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV REDIS_HOST=redis-cache
ENV BUNDLE_WITHOUT="development:test"

RUN apk add --no-cache \
    bash \
    geos \
    icu \
    jemalloc \
    nodejs \
    postgresql-client \
    su-exec \
    tzdata \
    xz-libs \
    yarn \
    zlib

WORKDIR /srv/app

RUN addgroup -S app && adduser -S app -G app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /srv/app/ /srv/app/

RUN rm -rf /srv/app/tmp /srv/app/spec /srv/app/node_modules /srv/app/log /srv/app/coverage


VOLUME /srv/app/public/uploads

# USER app

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

EXPOSE 8080

HEALTHCHECK \
    --start-interval=1s \
    --start-period=30s \
    --interval=30s \
    --timeout=20s \
    --retries=5 \
    CMD wget --no-verbose --tries=1 -O /dev/null http://127.0.0.1:8080/up || exit 1
