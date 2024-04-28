ARG NGINX_TAG


FROM docker.io/nginx:${NGINX_TAG}-bookworm as brotli-module
RUN set -ex \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install \
    -y --no-install-recommends \
          "wget" \
          "git" \
          "build-essential" \
          "libpcre3-dev" \
          "zlib1g-dev" \
          "libssl-dev" \
          "libgd-dev" \
          "libxml2-dev" \
          "uuid-dev" \
          "libxslt-dev" \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*
ARG NGINX_TAG
RUN wget "http://nginx.org/download/nginx-${NGINX_TAG}.tar.gz" \
    && tar -xzvf "nginx-${NGINX_TAG}.tar.gz"
RUN git clone https://github.com/google/ngx_brotli.git --recursive
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') \
    && cd "nginx-${NGINX_TAG}" \
    && ./configure --with-compat "${CONFARGS}" \
       --add-dynamic-module=../ngx_brotli \
    && make modules \
    && mv objs/ngx_http_brotli_filter_module.so \
       objs/ngx_http_brotli_static_module.so /



FROM docker.io/nginx:${NGINX_TAG}-bookworm as base
ARG NGINX_TAG
ARG GIT_COMMIT
LABEL org.hotosm.osm-sandbox.app-name="proxy" \
      org.hotosm.osm-sandbox-version="${NGINX_TAG}" \
      org.hotosm.osm-sandbox-commit-ref="${COMMIT_REF:-none}" \
      org.hotosm.osm-sandbox="sysadmin@hotosm.org"
# Install certbot, netcat
RUN set -ex \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install \
    -y --no-install-recommends \
          "netcat-traditional" \
          "certbot" \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*
# Add modules
COPY --from=brotli-module \
     /ngx_http_brotli_filter_module.so \
     /ngx_http_brotli_static_module.so \
     /usr/lib/nginx/modules/
WORKDIR /usr/share/nginx/html
# Remove default Nginx static assets
RUN rm -rf ./* /etc/nginx/conf.d/default.conf /etc/nginx/nginx.conf
COPY nginx.conf \
     options-ssl-nginx.conf \
     options-security.conf \
     certs/ssl-dhparams.pem \
     /etc/nginx/
# Add Healthcheck
HEALTHCHECK --start-period=5s --interval=5s --retries=8 \
    CMD nc -z localhost 80 || exit 1



FROM base as debug
COPY certs /etc/nginx/
COPY templates/osm-dev.conf.template \
     /etc/nginx/templates/



FROM base as certs-init
# Replace existing /docker-entrypoint.sh
COPY container-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
COPY templates/cert-init.conf.template \
     /etc/nginx/templates/



FROM base as latest
COPY templates/osm.conf.template \
     /etc/nginx/templates/
