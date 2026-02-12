ARG RUBY_IMAGE=3.1.7-alpine

FROM ruby:${RUBY_IMAGE}

ENTRYPOINT []
CMD ["/bin/bash"]

ARG RAILS_ENV
ARG NODE_ENV
ENV REDIS_HOST redis-cache

ENV NODE_OPTIONS=--openssl-legacy-provider

# Install development dependencies
RUN apk add --no-cache \
    bash \
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
    postgresql-client \
    tzdata \
    yarn \
    zlib-dev \
    vim \
    curl \
    wget

WORKDIR /srv/app

ADD ./package.json /srv/app/
RUN yarn install

ADD ./Gemfile /srv/app/
ADD ./Gemfile.lock /srv/app/

RUN bundle config git.allow_insecure true && \
    bundle install --full-index

ADD . /srv/app/

RUN bundle exec rake i18n:js:export && \
    bundle exec rake assets:precompile API_DOC_MODE=true

VOLUME /srv/app/public/uploads
