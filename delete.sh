#!/bin/bash

cd "$(dirname "$0")"

docker compose down -v --rmi all --remove-orphans 2>/dev/null || true

rm -f ssl/cert.pem ssl/key.pem 2>/dev/null || true
rm -f opendkim/keys/* 2>/dev/null || true
touch opendkim/keys/.gitkeep 2>/dev/null || true

echo -n "" > dovecot/passwd
echo -n "" > postfix/virtual_users

rm -f .env 2>/dev/null || true

echo "System reset complete."
