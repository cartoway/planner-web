ARG RUBY_IMAGE=3.1.7-alpine

FROM ruby:${RUBY_IMAGE}

ENTRYPOINT []
CMD ["/bin/bash"]

ARG RAILS_ENV
ARG NODE_ENV
ENV REDIS_HOST redis-cache

# Skip Uglifier (RAM-heavy + breaks on modern JS). jemalloc reduces Ruby RSS.
ENV NODE_OPTIONS=--openssl-legacy-provider \
    SKIP_JS_COMPRESSOR=1 \
    YARN_PRODUCTION=false \
    LD_PRELOAD=/usr/lib/libjemalloc.so.2

# Install development dependencies
RUN apk add --no-cache \
    bash \
    build-base \
    freetype \
    geos-dev \
    git \
    harfbuzz \
    icu-dev \
    imagemagick \
    imagemagick-heic \
    imagemagick-jpeg \
    imagemagick-webp \
    jemalloc-dev \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    nodejs \
    postgresql-dev \
    postgresql-client \
    ttf-dejavu \
    tzdata \
    weasyprint \
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

RUN chmod +x /srv/app/script/export_lookbook_visual_regression_report.rb && \
    find /srv/app/.devcontainer -maxdepth 1 -name '*.sh' -exec chmod +x {} +

# Sequential steps: webpack then sprockets+swagger — keeps peaks from overlapping.
# WEBPACK_LOW_MEMORY serializes webpack; max-old-space-size caps Node heap for this step only.
RUN bundle exec rake i18n:js:export
RUN WEBPACK_LOW_MEMORY=1 NODE_OPTIONS="$NODE_OPTIONS --max-old-space-size=1536" \
    bundle exec rails webpacker:compile
RUN API_DOC_MODE=true WEBPACKER_PRECOMPILE=false bundle exec rake assets:precompile

VOLUME /srv/app/public/uploads
