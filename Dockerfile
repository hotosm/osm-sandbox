ARG OSM_COMMIT_SHA=99a7d21a9bc50cdb38559dd0a8b60bc60072b5a1



FROM docker.io/ruby:3.3.0-slim-bookworm as openstreetmap-repo
RUN set -ex \
     && apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get install \
     -y --no-install-recommends \
          "curl" \
          "unzip" \
     && rm -rf /var/lib/apt/lists/*
WORKDIR /openstreetmap-website
ARG OSM_COMMIT_SHA
RUN curl -L \
     "https://github.com/openstreetmap/openstreetmap-website/archive/${OSM_COMMIT_SHA}.zip" \
     --output website.zip \
     && unzip website.zip \
     && mv openstreetmap-website-$OSM_COMMIT_SHA/* /openstreetmap-website/ \
     && rm website.zip



FROM docker.io/ruby:3.3.0-slim-bookworm as build
ENV RAILS_ENV=production 
ENV DEBIAN_FRONTEND=noninteractive
RUN set -ex \
     && apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get install \
     -y --no-install-recommends \
          "build-essential" \
          "software-properties-common" \
          "locales" \
          "tzdata" \
          "postgresql-client" \
          "nodejs" \
          "npm" \
          "curl" \
          "default-jre-headless" \
          "file" \
          "git-core" \
          "gpg-agent" \
          "libarchive-dev" \
          "libffi-dev" \
          "libgd-dev" \
          "libpq-dev" \
          "libsasl2-dev" \
          "libvips-dev" \
          "libxml2-dev" \
          "libxslt1-dev" \
          "libyaml-dev" \
     && rm -rf /var/lib/apt/lists/* \
     && npm install --global yarn
WORKDIR /app
COPY --from=openstreetmap-repo \
    /openstreetmap-website/ /app/
# Install Ruby packages
RUN bundle config set --global path /usr/local/bundle \
    && bundle install \
    # Install NodeJS packages using yarn
    && bundle exec bin/yarn install
# A dummy config is required for precompile step below
RUN cp config/example.database.yml config/database.yml \
    && touch config/settings.local.yml \
    && echo "#session key \n\
    production: \n\
      secret_key_base: $(bundle exec bin/rails secret)" > config/secrets.yml \
    # Precompile assets for faster initial load
    && bundle exec bin/rails i18n:js:export assets:precompile
# Package svgo dependency required by image_optim into node single file exe
RUN \
     mkdir /bins && cd /bins \
     # TODO update this to use node@21 single file executable?
     && npm install -g svgo @yao-pkg/pkg \
     && pkg -t node18-linux /usr/local/bin/svgo



FROM docker.io/ruby:3.3.0-slim-bookworm as runtime
ARG OSM_COMMIT_SHA
ARG GIT_COMMIT
LABEL org.hotosm.osm-sandbox.app-name="osm" \
      org.hotosm.osm-sandbox-version="${OSM_COMMIT_SHA}" \
      org.hotosm.osm-sandbox-commit-ref="${COMMIT_REF:-none}" \
      org.hotosm.osm-sandbox="sysadmin@hotosm.org"
ENV RAILS_ENV=production \
    PIDFILE=/tmp/pids/server.pid
RUN set -ex \
     && apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get install \
     -y --no-install-recommends \
          "locales" \
          "tzdata" \
          "postgresql-client" \
          "curl" \
          "libarchive-dev" \
          "libffi-dev" \
          "libgd-dev" \
          "libpq-dev" \
          "libsasl2-dev" \
          "libvips-dev" \
          "libxml2-dev" \
          "libxslt1-dev" \
          "libyaml-dev" \
          # Required image optimisation libraries in OSM prod
          "advancecomp" \
          "gifsicle" \
          "libjpeg-progs" \
          "jhead" \
          "jpegoptim" \
          "optipng" \
          "pngcrush" \
          "pngquant" \
     && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
COPY scripts /app/scripts
COPY osm-entrypoint.sh /
# Copy svgo requirement as single file executable
COPY --from=build /bins/svgo /usr/local/bin/svgo
RUN \
     bundle config set --global path /usr/local/bundle \
     # Copy the required config to correct location
     # https://github.com/openstreetmap/openstreetmap-website/blob/master/DOCKER.md#initial-setup
     && cp config/example.storage.yml config/storage.yml \
     && cp config/docker.database.yml config/database.yml \
     # Replace db --> osm-db compose network service name
     && sed -i 's/host: db/host: osm-db/' config/database.yml \
     && touch config/settings.local.yml \
     && chmod +x /osm-entrypoint.sh
ENTRYPOINT ["/osm-entrypoint.sh"]
CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]
