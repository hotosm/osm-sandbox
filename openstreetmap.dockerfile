FROM ubuntu:22.04 as openstreetmap-repo
RUN apt-get update \
 && apt-get install --no-install-recommends -y \
      git \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /repo
RUN update-ca-certificates
RUN git clone --depth 1 --no-checkout \
     https://github.com/openstreetmap/openstreetmap-website.git \
     && cd openstreetmap-website \
     && git checkout a5f72216395fb490a984dd86575f855c94a6a02f



# Modified from https://github.com/openstreetmap/openstreetmap-website
FROM ubuntu:22.04 as build
ENV DEBIAN_FRONTEND=noninteractive
# Install system packages then clean up to minimize image size
RUN apt-get update \
 && apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      default-jre-headless \
      file \
      git-core \
      gpg-agent \
      libarchive-dev \
      libffi-dev \
      libgd-dev \
      libpq-dev \
      libsasl2-dev \
      libvips-dev \
      libxml2-dev \
      libxslt1-dev \
      libyaml-dev \
      locales \
      postgresql-client \
      ruby \
      ruby-dev \
      ruby-bundler \
      software-properties-common \
      tzdata \
      unzip \
      nodejs \
      npm \
 && npm install --global yarn \
 # We can't use snap packages for firefox inside a container, so we need to get firefox+geckodriver elsewhere
 && add-apt-repository -y ppa:mozillateam/ppa \
 && echo "Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001" > /etc/apt/preferences.d/mozilla-firefox \
 && apt-get install --no-install-recommends -y \
      firefox-geckodriver \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=dialog
# Setup app location
WORKDIR /app
# Copy the app, as normally expected to be mounted
COPY --from=openstreetmap-repo \
    /repo/openstreetmap-website/ /app/
# Install Ruby packages
RUN bundle config set --global path /usr/local/bundle \
    && bundle install \
    # Install NodeJS packages using yarn
    && bundle exec bin/yarn install



FROM ubuntu:22.04 as runtime
ENV DEBIAN_FRONTEND=noninteractive \
    PIDFILE=/tmp/pids/server.pid
RUN apt-get update \
 && apt-get install --no-install-recommends -y \
      libarchive-dev \
      libffi-dev \
      libgd-dev \
      libpq-dev \
      libsasl2-dev \
      libvips-dev \
      libxml2-dev \
      libxslt1-dev \
      libyaml-dev \
      locales \
      tzdata \
      postgresql-client \
      ruby \
      ruby-bundler \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# COPY --from=build /app /app
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

CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]
ENTRYPOINT ["/osm-entrypoint.sh"]
