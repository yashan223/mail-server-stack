#!/bin/sh
set -e

DOMAIN=${DOMAIN:-example.com}
SELECTOR=${SELECTOR:-default}

echo "Starting OpenDKIM configuration for domain: ${DOMAIN}..."

mkdir -p /etc/opendkim/keys

if [ ! -f "/etc/opendkim/keys/${SELECTOR}.private" ]; then
    echo "No DKIM key found for selector '${SELECTOR}' and domain '${DOMAIN}'."
    echo "Generating a new 2048-bit DKIM key..."
    opendkim-genkey -b 2048 -d "${DOMAIN}" -s "${SELECTOR}" -D /etc/opendkim/keys
    
    mv "/etc/opendkim/keys/${SELECTOR}.private" "/etc/opendkim/keys/${SELECTOR}.private" 2>/dev/null || true
    
    echo "DKIM Key generated."
    echo "------------------------------------------------------------"
    echo "Add the following TXT record to your DNS zone for ${DOMAIN}:"
    echo ""
    cat "/etc/opendkim/keys/${SELECTOR}.txt"
    echo "------------------------------------------------------------"
fi

echo "Generating OpenDKIM KeyTable..."
echo "${SELECTOR}._domainkey.${DOMAIN} ${DOMAIN}:${SELECTOR}:/etc/opendkim/keys/${SELECTOR}.private" > /etc/opendkim/KeyTable

echo "Generating OpenDKIM SigningTable..."
echo "*@${DOMAIN} ${SELECTOR}._domainkey.${DOMAIN}" > /etc/opendkim/SigningTable

echo "Generating OpenDKIM TrustedHosts..."
cat <<EOF > /etc/opendkim/TrustedHosts
127.0.0.1
localhost
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
*.${DOMAIN}
EOF

echo "Setting permissions on OpenDKIM files..."
chown -R opendkim:opendkim /etc/opendkim
chmod 700 /etc/opendkim/keys
chmod 600 /etc/opendkim/keys/*.private 2>/dev/null || true
chmod 644 /etc/opendkim/keys/*.txt 2>/dev/null || true
chmod 644 /etc/opendkim/KeyTable /etc/opendkim/SigningTable /etc/opendkim/TrustedHosts

echo "OpenDKIM configuration complete. Starting daemon..."
exec opendkim -f -u opendkim -p inet:8891@0.0.0.0
