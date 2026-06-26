FROM alpine:3.18

RUN apk add --no-cache \
    opendkim \
    opendkim-utils \
    ca-certificates \
    tzdata

COPY opendkim.conf /etc/opendkim/opendkim.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 8891

ENTRYPOINT ["/entrypoint.sh"]
