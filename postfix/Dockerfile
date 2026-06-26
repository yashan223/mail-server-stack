FROM alpine:3.18

RUN apk add --no-cache \
    postfix \
    openssl \
    ca-certificates \
    tzdata

COPY main.cf /etc/postfix/main.cf
COPY master.cf /etc/postfix/master.cf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 25 465 587

ENTRYPOINT ["/entrypoint.sh"]
