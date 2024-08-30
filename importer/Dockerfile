FROM docker.io/debian:bookworm-slim
RUN set -ex \
     && apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get install \
     -y --no-install-recommends \
          "ca-certificates" \
          "curl" \
          "osmosis" \
          "osmium-tool" \
     && rm -rf /var/lib/apt/lists/* \
     && update-ca-certificates
