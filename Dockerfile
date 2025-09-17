# Step 1: Build (assets, gems, node_modules)
FROM ruby:3.1.7-alpine AS builder
ENV NODE_OPTIONS=--openssl-legacy-provider

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    postgresql-dev \
    nodejs \
    yarn \
    libxml2-dev \
    libxslt-dev \
    libffi-dev \
    tzdata \
    geos-dev \
    jemalloc-dev \
    icu-dev \
    zlib-dev

WORKDIR /srv/app

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local no-doc 'true' && \
    bundle install --jobs=4 --retry=3 && \
    rm -rf /usr/local/bundle/cache/*.gem /usr/local/bundle/doc

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile && \
    yarn cache clean

COPY . .

RUN bundle exec rake i18n:js:export && \
    bundle exec rake assets:precompile API_DOC_MODE=true

# Step 2: Final image, minimal
FROM ruby:3.1.7-alpine

RUN apk add --no-cache \
    postgresql-client \
    nodejs \
    yarn \
    tzdata \
    geos \
    jemalloc \
    icu \
    zlib \
    su-exec

WORKDIR /srv/app

RUN addgroup -S app && adduser -S app -G app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /srv/app/public /srv/app/public
COPY --from=builder /srv/app/app /srv/app/app
COPY --from=builder /srv/app/config /srv/app/config
COPY --from=builder /srv/app/lib /srv/app/lib
COPY --from=builder /srv/app/bin /srv/app/bin
COPY --from=builder /srv/app/db /srv/app/db
COPY --from=builder /srv/app/vendor /srv/app/vendor

RUN rm -rf /srv/app/tmp /srv/app/spec /srv/app/test /srv/app/node_modules /srv/app/log /srv/app/coverage

ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV REDIS_HOST=redis-cache

VOLUME /srv/app/public/uploads

USER app

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
