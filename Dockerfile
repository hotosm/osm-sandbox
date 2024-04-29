ARG OSM_COMMIT_DATE=2024-04-28
ARG OSM_COMMIT=2bb4ca45b35fe303f22afbf8139c9beda7dfbda6


FROM docker.io/ruby:3.3.0-slim-bookworm as openstreetmap-repo
RUN set -ex \
     && apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get install \
     -y --no-install-recommends \
          "git" \
          "ca-certificates" \
     && rm -rf /var/lib/apt/lists/*
WORKDIR /repo
RUN update-ca-certificates
ARG OSM_COMMIT
ARG OSM_COMMIT_DATE
RUN git clone --branch master --shallow-since="${OSM_COMMIT_DATE}" \
     https://github.com/openstreetmap/openstreetmap-website.git \
     && cd openstreetmap-website && git checkout "${OSM_COMMIT}"



FROM docker.io/ruby:3.3.0-slim-bookworm as build
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
    /repo/openstreetmap-website/ /app/
# Install Ruby packages
RUN bundle config set --global path /usr/local/bundle \
    && bundle install \
    # Install NodeJS packages using yarn
    && bundle exec bin/yarn install



FROM docker.io/ruby:3.3.0-slim-bookworm as runtime
ARG OSM_COMMIT
ARG GIT_COMMIT
LABEL org.hotosm.osm-sandbox.app-name="osm" \
      org.hotosm.osm-sandbox-version="${OSM_COMMIT}" \
      org.hotosm.osm-sandbox-commit-ref="${COMMIT_REF:-none}" \
      org.hotosm.osm-sandbox="sysadmin@hotosm.org"
ENV PIDFILE=/tmp/pids/server.pid
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
     && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/Gemfile* /app/Rakefile /app/config.ru /app/
COPY --from=build /app/node_modules /app/node_modules
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app/app /app/app
COPY --from=build /app/bin /app/bin
COPY --from=build /app/config /app/config
COPY --from=build /app/db /app/db
COPY --from=build /app/lib /app/lib
COPY --from=build /app/public /app/public
COPY --from=build /app/script /app/script
COPY --from=build /app/vendor /app/vendor
COPY osm-entrypoint.sh /
RUN bundle config set --global path /usr/local/bundle \
     # Copy the required config to correct location
     # https://github.com/openstreetmap/openstreetmap-website/blob/master/DOCKER.md#initial-setup
     && cp config/example.storage.yml config/storage.yml \
     && cp config/docker.database.yml config/database.yml \
     # Replace db --> osm-db compose service
     && sed -i 's/host: db/host: osm-db/' config/database.yml \
     && touch config/settings.local.yml \
     && chmod +x /osm-entrypoint.sh
ENTRYPOINT ["/osm-entrypoint.sh"]
CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]
