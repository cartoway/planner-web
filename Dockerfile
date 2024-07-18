FROM ruby:2.7-bullseye
ENTRYPOINT []
CMD ["/bin/bash"]

ARG RAILS_ENV
ARG NODE_ENV
ENV REDIS_HOST redis-cache

RUN apt update && \
    apt install -y \
        git build-essential \
        zlib1g-dev libicu-dev g++ libgeos-dev libgeos++-dev libpq-dev \
        zlib1g libicu67 libgeos-3.9.0 libpq5 postgresql-client \
        libjemalloc2 \
        nodejs yarnpkg && \
    ln -s /usr/bin/yarnpkg /usr/bin/yarn

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
# Prepare configuration files
ADD ./config/database.yml.docker config/database.yml

VOLUME /srv/app/public/uploads
