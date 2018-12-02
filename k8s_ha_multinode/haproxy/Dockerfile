# vim:set ft=dockerfile:
FROM haproxy:1.8.14-alpine
ENV HAPROXY_USER=haproxy
ENV HAPROXY_CONFIG=
ENV HAPROXY_ARGS=
RUN apk --update add curl
RUN mkdir -p /run/haproxy &&  mkdir -p /usr/local/etc/default &&  echo 'ENABLED=1' > /usr/local/etc/default/haproxy 
RUN addgroup ${HAPROXY_USER} &&  adduser -D -G ${HAPROXY_USER} ${HAPROXY_USER} &&  mkdir -p /var/lib/${HAPROXY_USER} &&  chown -R ${HAPROXY_USER}:${HAPROXY_USER} /var/lib/${HAPROXY_USER}
EXPOSE 443 80 8080 8181
CMD ["/bin/sh", "-c", "haproxy -f $HAPROXY_CONFIG $HAPROXY_ARGS"]



