FROM debian:12
RUN apt update -y && apt install -y nginx libnginx-mod-http-lua lua-cjson
RUN mkdir -p /var/cache/nginx/planner__internal_auth && \
    ln -s /etc/nginx/modules-enabled/10-mod-http-ndk.conf /etc/nginx/modules-available/10-mod-http-ndk.conf && \
    ln -s /etc/nginx/modules-enabled/50-mod-http-lua.conf /etc/nginx/modules-available/50-mod-http-lua.conf
ADD superset.conf /etc/nginx/sites-available/default

CMD nginx -g 'daemon off;'
