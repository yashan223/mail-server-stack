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
   *Roundcube Webmail will be accessible at: `http://mail.example.com` (redirects to `https://mail.example.com` once SSL is set up)*

---

## SSL/TLS with Certbot (Let's Encrypt)

The stack is pre-configured to dynamically load official Let's Encrypt certificates from the host VPS `/etc/letsencrypt` directory.

To use Certbot:

1. **Generate Certificate on the VPS Host**:
   Stop any local web servers (so Certbot can bind to port 80) and run:
   ```bash
   sudo systemctl stop nginx || true
   sudo systemctl stop apache2 || true
   sudo certbot certonly --standalone -d mail.example.com
   ```

2. **Run Stack**:
   Once the certificates are generated on the host, the containers will automatically read them on startup. No manual volume modifications are required.

3. **Configure Auto-Reload**:
   Add this deploy hook to `/etc/letsencrypt/cli.ini` (or pass as `--deploy-hook` to Certbot) to hot-reload the mail containers upon successful renewal:
   ```ini
   deploy-hook = docker compose -f /path/to/mail-server-stack/docker-compose.yml exec -T postfix postfix reload && docker compose -f /path/to/mail-server-stack/docker-compose.yml exec -T dovecot dovecot reload && docker compose -f /path/to/mail-server-stack/docker-compose.yml exec -T nginx nginx -s reload
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
