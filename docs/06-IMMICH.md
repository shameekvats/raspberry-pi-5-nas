# Immich

Immich is a self-hosted photo and video backup solution — a privacy-first replacement for Google Photos, with facial recognition, map view, and a mobile app with automatic camera roll backup.

---

## Compose File

Immich publishes an official compose file that is updated with each release. Always use the official version rather than copying from tutorials (it changes frequently).

```bash
mkdir -p /srv/mergerfs/storage-pool/Docker/Compose/immich
cd /srv/mergerfs/storage-pool/Docker/Compose/immich

# Download the official compose file and example env
wget https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
wget https://github.com/immich-app/immich/releases/latest/download/example.env -O .env
```

Edit the `.env` file:

```bash
nano .env
```

Key values to set:

```env
# Path where photos will be stored — point to the NAS pool
UPLOAD_LOCATION=/srv/mergerfs/storage-pool/Photos

# Database password — set a strong value
DB_PASSWORD=<STRONG_DB_PASSWORD>

# Timezone
TZ=Europe/Luxembourg
```

> The `DB_DATA_LOCATION` default puts the database in `./postgres`. If you want the database on the secondary SSD to reduce writes to the pool, change it:
> ```env
> DB_DATA_LOCATION=/srv/dev-disk-by-uuid-<PARITY-UUID>/docker/immich-postgres
> ```

---

## Deploy

```bash
cd /srv/mergerfs/storage-pool/Docker/Compose/immich
docker compose up -d
```

Immich pulls several images (server, machine learning, database, Redis) — first pull takes 5–10 minutes.

Follow logs:
```bash
docker compose logs -f
```

Access at `http://pi5-nas.local:2283` once the server container shows "Listening on port 2283".

---

## First-Time Setup

1. Open `http://pi5-nas.local:2283`
2. Create an admin account
3. Complete the welcome wizard
4. The Photos folder on the NAS pool is your upload destination

---

## Mobile App

1. Install **Immich** from the App Store or Google Play
2. Server URL: `http://pi5-nas.local:2283` (local) or `http://<TAILSCALE_IP>:2283` (remote)
3. Log in with your admin credentials
4. Enable **Backup** in the app settings
5. Configure which albums/sources to back up

**Recommended backup settings:**
- Camera Roll: ✅ Enable
- Require WiFi: ✅ Enable (prevents mobile data usage)
- Background backup: Enable if your phone OS allows it

---

## Configure Backup Selectivity

To avoid backing up screenshots, WhatsApp images, etc.:

1. **Immich app → Account → Backup → Albums**
2. Disable albums you don't want backed up
3. Only "Camera" or "Recents" typically needed

---

## Machine Learning Features

Immich includes a machine learning container that provides:
- **Facial recognition** — groups photos by person
- **CLIP semantic search** — search by description (e.g. "beach sunset")
- **Smart albums** — automatically categorized content

On a Pi 5, machine learning tasks run on the CPU. Initial indexing of a large library (10,000+ photos) takes several hours but runs in the background and does not affect normal access.

Monitor progress:
```bash
docker logs -f immich_machine_learning
```

---

## Storage Layout

```
/srv/mergerfs/storage-pool/Photos/     ← UPLOAD_LOCATION
├── upload/                             ← Immich managed
│   ├── <user-uuid>/
│   │   └── YYYY/MM/DD/
│   │       └── original files
├── thumbs/                             ← Generated thumbnails
├── profile/                            ← Profile pictures
└── encoded-video/                      ← Transcoded videos
```

---

## Updating Immich

Immich releases updates frequently. Update monthly or when notified of security releases:

```bash
cd /srv/mergerfs/storage-pool/Docker/Compose/immich
docker compose pull
docker compose up -d
```

Immich handles database migrations automatically on startup. Always check the [release notes](https://github.com/immich-app/immich/releases) before major version upgrades.

---

## Useful Admin Tasks

```bash
# Check all container status
docker compose ps

# View server logs
docker compose logs -f immich_server

# Database backup (run before upgrades)
docker exec immich_postgres pg_dumpall -U postgres > immich-backup-$(date +%Y%m%d).sql
```

---

**Next step:** [Home Assistant](07-HOME-ASSISTANT.md)
