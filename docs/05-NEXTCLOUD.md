# Nextcloud

Nextcloud is a self-hosted file sync and collaboration platform — a privacy-respecting replacement for Google Drive or iCloud Drive.

---

## Compose File

Create the directory and compose file:

```bash
sudo mkdir -p /srv/mergerfs/storage-pool/Docker/Compose/nextcloud
nano /srv/mergerfs/storage-pool/Docker/Compose/nextcloud/docker-compose.yml
```

```yaml
version: '3'

services:
  nextcloud-db:
    image: mariadb:10.11
    container_name: nextcloud-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: <STRONG_ROOT_PASSWORD>
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: <STRONG_DB_PASSWORD>
    volumes:
      - nextcloud-db:/var/lib/mysql

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    ports:
      - "8080:80"
    depends_on:
      - nextcloud-db
    environment:
      MYSQL_HOST: nextcloud-db
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: <STRONG_DB_PASSWORD>
    volumes:
      - nextcloud-app:/var/www/html
      - /srv/mergerfs/storage-pool/Documents:/var/www/html/data/nas_documents
      - /srv/mergerfs/storage-pool/Photos:/var/www/html/data/nas_photos

volumes:
  nextcloud-db:
  nextcloud-app:
```

> Replace `<STRONG_ROOT_PASSWORD>` and `<STRONG_DB_PASSWORD>` with strong, unique passwords. Store them securely — not in this file if you plan to commit it.

**Deploy:**

```bash
cd /srv/mergerfs/storage-pool/Docker/Compose/nextcloud
docker compose up -d
```

Watch startup logs:
```bash
docker logs -f nextcloud
```

---

## First-Time Setup

1. Open `http://pi5-nas.local:8080`
2. Create an admin account (choose a strong password)
3. Database configuration is handled automatically via environment variables
4. Wait for Nextcloud to finish initializing (can take 1–2 minutes on first launch)

---

## Configure External Storage (NAS Shares in Nextcloud)

To make the NAS pool folders appear as storage locations inside Nextcloud:

1. **Apps → search for "External storage support"** → Enable it
2. **Settings (gear icon) → Administration → External Storages**
3. Add two entries:

| Folder name | External storage | Authentication | Configuration |
|---|---|---|---|
| NAS Documents | Local | None | `/var/www/html/data/nas_documents` |
| NAS Photos | Local | None | `/var/www/html/data/nas_photos` |

4. Set applicable users to "All users"
5. Save — the folders appear in every user's Nextcloud Files view

---

## Fix Write Permissions

If Nextcloud cannot write to the NAS folders:

```bash
# Give the Nextcloud container (www-data, uid 33) access to the pool
sudo chown -R 33:33 /srv/mergerfs/storage-pool/Documents
sudo chown -R 33:33 /srv/mergerfs/storage-pool/Photos
sudo chmod -R 775 /srv/mergerfs/storage-pool/Documents
sudo chmod -R 775 /srv/mergerfs/storage-pool/Photos
```

Or if you want both Nextcloud and SMB to write:

```bash
sudo usermod -aG www-data <YOUR_NAS_USERNAME>
sudo chmod -R 775 /srv/mergerfs/storage-pool/Documents
sudo chmod -R 775 /srv/mergerfs/storage-pool/Photos
```

Restart the Nextcloud container after permission changes:

```bash
docker restart nextcloud
```

---

## Add Trusted Domains

By default, Nextcloud only accepts requests from `localhost`. Add your NAS hostname and Tailscale address:

```bash
docker exec -it nextcloud bash
```

Inside the container:

```bash
php occ config:system:set trusted_domains 1 --value="pi5-nas.local"
php occ config:system:set trusted_domains 2 --value="<YOUR_NAS_IP>"
php occ config:system:set trusted_domains 3 --value="<YOUR_TAILSCALE_IP>"
exit
```

Or edit `config/config.php` directly in the `nextcloud-app` Docker volume:

```php
'trusted_domains' =>
  array (
    0 => 'localhost',
    1 => 'pi5-nas.local',
    2 => '<YOUR_NAS_IP>',
    3 => '<YOUR_TAILSCALE_IP>',
  ),
```

---

## Enable File Previews

To enable thumbnail generation for images and documents:

```bash
docker exec -it nextcloud bash
php occ config:system:set enable_previews --value=true --type=boolean
php occ config:system:set preview_max_x --value=2048
php occ config:system:set preview_max_y --value=2048
exit
```

---

## Mobile & Desktop Clients

- **iOS / Android:** Nextcloud app — available in App Store and Google Play
- **macOS / Windows / Linux:** Nextcloud Desktop client — [nextcloud.com/install](https://nextcloud.com/install/#install-clients)

Server address during setup: `http://pi5-nas.local:8080` (local) or `http://<TAILSCALE_IP>:8080` (remote)

---

## Maintenance Commands

```bash
# Run background jobs manually
docker exec -it nextcloud php occ maintenance:mode --on
docker exec -it nextcloud php occ upgrade
docker exec -it nextcloud php occ maintenance:mode --off

# Scan for new files added outside of Nextcloud (e.g. via SMB)
docker exec -it nextcloud php occ files:scan --all

# Check overall system status
docker exec -it nextcloud php occ status
```

---

**Next step:** [Immich](06-IMMICH.md)
