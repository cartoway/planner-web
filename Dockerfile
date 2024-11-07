FROM ruby:3.1
ENTRYPOINT []
CMD ["/bin/bash"]

ARG RAILS_ENV
ARG NODE_ENV
ENV REDIS_HOST redis-cache

ENV NODE_OPTIONS=--openssl-legacy-provider

RUN apt update && \
    apt install -y \
        git build-essential lsb-release \
        zlib1g-dev libicu-dev g++ libgeos-dev libgeos++-dev libpq-dev \
        zlib1g libicu72 libgeos3.11.1 libpq5 libjemalloc2 \
        nodejs yarnpkg && \
    ln -s /usr/bin/yarnpkg /usr/bin/yarn

RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
apt update && \
apt install -y postgresql-client-15

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
