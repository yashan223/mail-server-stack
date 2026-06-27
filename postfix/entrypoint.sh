#!/bin/sh
set -e

DOMAIN=${DOMAIN:-example.com}
HOSTNAME=${HOSTNAME:-mail.example.com}

echo "Starting Postfix configuration for domain: ${DOMAIN}, hostname: ${HOSTNAME}..."

postconf -e "myhostname = ${HOSTNAME}"
postconf -e "mydomain = ${DOMAIN}"
postconf -e "myorigin = \$mydomain"
postconf -e "mydestination = localhost.\$mydomain, localhost"

SSL_DIR="/etc/ssl/mail"
LE_DIR="/etc/letsencrypt/live/${HOSTNAME}"

if [ -f "${LE_DIR}/fullchain.pem" ] && [ -f "${LE_DIR}/privkey.pem" ]; then
    echo "Found Let's Encrypt certificates in ${LE_DIR}. Symlinking to ${SSL_DIR}..."
    mkdir -p "${SSL_DIR}"
    rm -f "${SSL_DIR}/cert.pem" "${SSL_DIR}/key.pem"
    ln -sf "${LE_DIR}/fullchain.pem" "${SSL_DIR}/cert.pem"
    ln -sf "${LE_DIR}/privkey.pem" "${SSL_DIR}/key.pem"
    
    postconf -e "smtpd_tls_cert_file = ${SSL_DIR}/cert.pem"
    postconf -e "smtpd_tls_key_file = ${SSL_DIR}/key.pem"
    postconf -e "smtpd_tls_security_level = may"
    postconf -e "smtpd_use_tls = yes"
elif [ -f "${SSL_DIR}/cert.pem" ] && [ -f "${SSL_DIR}/key.pem" ]; then
    echo "Found SSL certificates in ${SSL_DIR}. Configuring Postfix to use them..."
    postconf -e "smtpd_tls_cert_file = ${SSL_DIR}/cert.pem"
    postconf -e "smtpd_tls_key_file = ${SSL_DIR}/key.pem"
    postconf -e "smtpd_tls_security_level = may"
    postconf -e "smtpd_use_tls = yes"
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
    
    postconf -e "smtpd_tls_cert_file = ${SSL_DIR}/cert.pem"
    postconf -e "smtpd_tls_key_file = ${SSL_DIR}/key.pem"
    postconf -e "smtpd_tls_security_level = may"
    postconf -e "smtpd_use_tls = yes"
fi

postfix check

echo "Postfix configuration complete. Starting daemon..."
exec postfix start-fg
