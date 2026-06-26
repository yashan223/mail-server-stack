# Mail Server Stack

A mail server stack (Postfix, Dovecot, OpenDKIM, Roundcube) orchestrated with Docker Compose.

---

## Quickstart

1. **Setup Environment**:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and set your `DOMAIN` and `HOSTNAME`.

2. **Add Mail User**:
   ```bash
   chmod +x setup.sh delete.sh
   ./setup.sh add-user admin@example.com password123
   ```

3. **Start Stack**:
   ```bash
   docker compose up -d --build
   ```
   *Roundcube Webmail will be accessible at: `http://localhost:8080`*

---

## SSL/TLS with Certbot (Let's Encrypt)

To use Certbot on the host:

1. **Generate Certificate**:
   ```bash
   sudo certbot certonly --standalone -d mail.example.com
   ```

2. **Update Volumes in `docker-compose.yml`**:
   Replace the local `./ssl` volume mount with the Let's Encrypt paths in both the `postfix` and `dovecot` services:
   ```yaml
       volumes:
         - mail-data:/var/mail
         - dovecot-sockets:/var/run/dovecot
         - /etc/letsencrypt/live/mail.example.com/fullchain.pem:/etc/ssl/mail/cert.pem:ro
         - /etc/letsencrypt/live/mail.example.com/privkey.pem:/etc/ssl/mail/key.pem:ro
   ```

3. **Configure Auto-Reload**:
   Add this deploy hook to `/etc/letsencrypt/cli.ini` (or pass as `--deploy-hook` to Certbot) to hot-reload services upon successful renewal:
   ```ini
   deploy-hook = docker compose -f /path/to/mail-server-stack/docker-compose.yml exec -T postfix postfix reload && docker compose -f /path/to/mail-server-stack/docker-compose.yml exec -T dovecot dovecot reload
   ```

---

## Management CLI (`setup.sh`)

- **Add/Update User**: `./setup.sh add-user [email] [password]`
- **List Users**: `./setup.sh list-users`
- **Delete User**: `./setup.sh del-user [email]`
- **Show DKIM DNS Record**: `./setup.sh dkim-dns`
- **Show DNS Guide**: `./setup.sh dns-guide`
- **Hot-Reload Services**: `./setup.sh reload`

---

## Reset / Delete Stack (`delete.sh`)

To stop the containers, remove all persistent volumes, delete generated SSL/DKIM keys, and clear the user database:
```bash
./delete.sh
```

---

## DNS Requirements

| Record | Type | Host | Value |
| :--- | :--- | :--- | :--- |
| **MX** | MX | `@` | `10 mail.yourdomain.com.` |
| **A** | A | `mail` | `<YOUR_SERVER_PUBLIC_IP>` |
| **SPF** | TXT | `@` | `"v=spf1 mx ip4:<YOUR_SERVER_PUBLIC_IP> ~all"` |
| **DKIM** | TXT | `default._domainkey` | *Retrieve using: `./setup.sh dkim-dns`* |
| **DMARC** | TXT | `_dmarc` | `"v=DMARC1; p=quarantine; pct=100; rua=mailto:postmaster@yourdomain.com"` |
