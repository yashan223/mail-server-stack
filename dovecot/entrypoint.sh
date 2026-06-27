#!/bin/sh
set -e

DOMAIN=${DOMAIN:-example.com}
HOSTNAME=${HOSTNAME:-mail.example.com}

echo "Starting Dovecot configuration..."

if ! getent group vmail >/dev/null; then
    echo "Creating group vmail (GID 5000)..."
    addgroup -g 5000 vmail
fi
if ! getent passwd vmail >/dev/null; then
    echo "Creating user vmail (UID 5000)..."
    adduser -u 5000 -G vmail -D -H -s /sbin/nologin vmail
fi

echo "Setting permissions on /var/mail to vmail:vmail..."
mkdir -p /var/mail/vhosts
chown -R vmail:vmail /var/mail
chmod 770 /var/mail || true
chown -R vmail:vmail /var/mail/vhosts
chmod 770 /var/mail/vhosts

SSL_DIR="/etc/ssl/mail"
LE_DIR="/etc/letsencrypt/live/${HOSTNAME}"

if [ -f "${LE_DIR}/fullchain.pem" ] && [ -f "${LE_DIR}/privkey.pem" ]; then
    echo "Found Let's Encrypt certificates in ${LE_DIR}. Symlinking to ${SSL_DIR}..."
    mkdir -p "${SSL_DIR}"
    rm -f "${SSL_DIR}/cert.pem" "${SSL_DIR}/key.pem"
    ln -sf "${LE_DIR}/fullchain.pem" "${SSL_DIR}/cert.pem"
    ln -sf "${LE_DIR}/privkey.pem" "${SSL_DIR}/key.pem"
elif [ -f "${SSL_DIR}/cert.pem" ] && [ -f "${SSL_DIR}/key.pem" ]; then
    echo "Found SSL certificates in ${SSL_DIR}. Configuring Dovecot to use them..."
else
    echo "WARNING: SSL certificates (cert.pem / key.pem) not found in ${SSL_DIR}."
    echo "Generating temporary self-signed certificates for testing..."
    mkdir -p "${SSL_DIR}"
    openssl req -new -x509 -nodes -days 365 \
        -subj "/C=US/ST=State/L=City/O=MailServer/CN=${HOSTNAME}" \
        -keyout "${SSL_DIR}/key.pem" \
        -out "${SSL_DIR}/cert.pem" 2>/dev/null
    
    chmod 600 "${SSL_DIR}/key.pem"
    chmod 644 "${SSL_DIR}/cert.pem"
fi

PASSWD_FILE="/etc/dovecot/passwd"
if [ ! -f "${PASSWD_FILE}" ]; then
    echo "Creating empty passwd file at ${PASSWD_FILE}..."
    touch "${PASSWD_FILE}"
fi
chown dovecot:dovecot "${PASSWD_FILE}"
chmod 600 "${PASSWD_FILE}"

mkdir -p /var/run/dovecot
chown -R root:root /var/run/dovecot
chmod 755 /var/run/dovecot

echo "Dovecot configuration complete. Starting daemon..."
exec dovecot -F
