#!/bin/bash

cd "$(dirname "$0")"

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

DOMAIN=${DOMAIN:-example.com}
HOSTNAME=${HOSTNAME:-mail.example.com}

show_help() {
    echo "Mail Server Stack CLI"
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "Commands:"
    echo "  add-user [email] [password]   Add a new virtual mail user"
    echo "  list-users                    List all configured mail accounts"
    echo "  del-user [email]              Delete a mail account"
    echo "  dkim-dns                      Show the DKIM public key and DNS record details"
    echo "  dns-guide                     Show a complete guide for DNS records (MX, SPF, DKIM, DMARC)"
    echo "  reload                        Reload Postfix and Dovecot configurations"
}

add_user() {
    local email="$1"
    local password="$2"

    if [ -z "$email" ]; then
        read -p "Enter email address (e.g. user@${DOMAIN}): " email
    fi

    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "Error: Invalid email format."
        exit 1
    fi

    local user_domain=$(echo "$email" | cut -d'@' -f2)

    if [ -z "$password" ]; then
        read -sp "Enter password for ${email}: " password
        echo ""
    fi

    if [ -z "$password" ]; then
        echo "Error: Password cannot be empty."
        exit 1
    fi

    echo "Generating secure SHA512-CRYPT password hash using Dovecot..."
    local hash=$(docker compose run --rm --entrypoint "" dovecot doveadm pw -s SHA512-CRYPT -p "$password")
    
    if [ -z "$hash" ]; then
        echo "Error: Failed to generate password hash."
        exit 1
    fi

    mkdir -p dovecot postfix
    touch dovecot/passwd postfix/virtual_users

    # Always prune existing entries to prevent duplicates
    sed -i.bak "/^${email}:/d" dovecot/passwd 2>/dev/null && rm -f dovecot/passwd.bak || true
    sed -i.bak "/^${email}[[:space:]]/d" postfix/virtual_users 2>/dev/null && rm -f postfix/virtual_users.bak || true

    echo "${email}:${hash}:5000:5000::/var/mail/vhosts/%d/%n" >> dovecot/passwd
    echo "${email}   dummy" >> postfix/virtual_users

    echo "User ${email} successfully created/updated."
    
    if [ "$(docker compose ps -q postfix 2>/dev/null)" ] && [ "$(docker compose ps -q dovecot 2>/dev/null)" ]; then
        echo "Reloading Postfix and Dovecot..."
        docker compose exec postfix postfix reload >/dev/null 2>&1 || true
        docker compose exec dovecot dovecot reload >/dev/null 2>&1 || true
        echo "Configurations reloaded."
    fi
}

list_users() {
    if [ ! -f dovecot/passwd ] || [ ! -s dovecot/passwd ]; then
        echo "No mail accounts configured."
        return
    fi
    echo "Configured Mail Accounts:"
    echo "-----------------------------------"
    grep -v '^#' dovecot/passwd | cut -d':' -f1
    echo "-----------------------------------"
}

del_user() {
    local email="$1"
    if [ -z "$email" ]; then
        read -p "Enter email address to delete: " email
    fi

    if [ ! -f dovecot/passwd ]; then
        echo "No users database found."
        exit 1
    fi

    if ! grep -q "^${email}:" dovecot/passwd; then
        echo "User ${email} not found."
        exit 1
    fi

    sed -i.bak "/^${email}:/d" dovecot/passwd && rm -f dovecot/passwd.bak
    sed -i.bak "/^${email}[[:space:]]/d" postfix/virtual_users && rm -f postfix/virtual_users.bak

    echo "User ${email} successfully deleted."
    
    if [ "$(docker compose ps -q postfix 2>/dev/null)" ] && [ "$(docker compose ps -q dovecot 2>/dev/null)" ]; then
        docker compose exec postfix postfix reload >/dev/null 2>&1 || true
        docker compose exec dovecot dovecot reload >/dev/null 2>&1 || true
        echo "Configurations reloaded."
    fi
}

dkim_dns() {
    local key_file="opendkim/keys/default.txt"
    if [ ! -f "$key_file" ]; then
        echo "DKIM public key not found. Please start the docker containers first,"
        echo "which will auto-generate the keys on their first run, or check your path."
        exit 1
    fi

    echo "========================================================================="
    echo "DKIM DNS TXT RECORD"
    echo "========================================================================="
    echo "Host/Name:   default._domainkey"
    echo "Type:        TXT"
    echo "Value/Text:"
    grep -v '^;' "$key_file" | tr -d '\n\t"' | sed 's/.*( \(.*\) ).*/\1/' | sed 's/ //g'
    echo ""
    echo "========================================================================="
}

dns_guide() {
    echo "========================================================================="
    echo "RECOMMENDED DNS CONFIGURATION GUIDE FOR ${DOMAIN}"
    echo "========================================================================="
    echo ""
    echo "1. MX Record (Mail Exchanger - points to your mail server)"
    echo "   Host/Name:   @"
    echo "   Type:        MX"
    echo "   Priority:    10"
    echo "   Value/Text:  ${HOSTNAME}."
    echo ""
    echo "2. A Record (Points your mail subdomain to your server's public IP)"
    echo "   Host/Name:   $(echo "$HOSTNAME" | cut -d'.' -f1)"
    echo "   Type:        A"
    echo "   Value/Text:  <YOUR_SERVER_PUBLIC_IP>"
    echo ""
    echo "3. SPF Record (Sender Policy Framework - authorizes your server to send mail)"
    echo "   Host/Name:   @"
    echo "   Type:        TXT"
    echo "   Value/Text:  \"v=spf1 mx ip4:<YOUR_SERVER_PUBLIC_IP> ~all\""
    echo ""
    echo "4. DKIM Record (DomainKeys Identified Mail - signs your mail)"
    echo "   Host/Name:   default._domainkey"
    echo "   Type:        TXT"
    if [ -f opendkim/keys/default.txt ]; then
        echo -n "   Value/Text:  \""
        grep -v '^;' opendkim/keys/default.txt | tr -d '\n\t"' | sed 's/.*( \(.*\) ).*/\1/' | sed 's/ //g'
        echo "\""
    else
        echo "   Value/Text:  <Run docker-compose to generate the public key, then run: $0 dkim-dns>"
    fi
    echo ""
    echo "5. DMARC Record (Domain-based Message Authentication - anti-spoofing policy)"
    echo "   Host/Name:   _dmarc"
    echo "   Type:        TXT"
    echo "   Value/Text:  \"v=DMARC1; p=quarantine; pct=100; rua=mailto:postmaster@${DOMAIN}\""
    echo ""
    echo "========================================================================="
}

reload_services() {
    if [ "$(docker compose ps -q postfix 2>/dev/null)" ] && [ "$(docker compose ps -q dovecot 2>/dev/null)" ]; then
        echo "Reloading Postfix and Dovecot configurations..."
        docker compose exec postfix postfix reload
        docker compose exec dovecot dovecot reload
        echo "Services reloaded."
    else
        echo "Services are not running. Run 'docker compose up -d' first."
    fi
}

case "$1" in
    add-user)
        add_user "$2" "$3"
        ;;
    list-users)
        list_users
        ;;
    del-user)
        del_user "$2"
        ;;
    dkim-dns)
        dkim_dns
        ;;
    dns-guide)
        dns_guide
        ;;
    reload)
        reload_services
        ;;
    *)
        show_help
        ;;
esac
