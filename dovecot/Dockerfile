FROM alpine:3.18

RUN apk add --no-cache \
    dovecot \
    dovecot-lmtp \
    openssl \
    ca-certificates \
    tzdata

COPY dovecot.conf /etc/dovecot/dovecot.conf
COPY conf.d/ /etc/dovecot/conf.d/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 143 993

ENTRYPOINT ["/entrypoint.sh"]
