# Docker & Portainer

All applications in this project run as Docker containers, managed through OMV-Extras and Portainer.

---

## Step 1 — Install Docker via OMV-Extras

1. **System → omv-extras**
2. Click the **Docker** tab
3. Click **Install Docker**
4. Wait 5–10 minutes for installation
5. Status should change to "Docker is installed"

---

## Step 2 — Move Docker Root to the Secondary SSD

By default, Docker stores all images and container data on the SD card. This will wear out the SD card quickly. Move the Docker root to the secondary SSD before pulling any images.

```bash
# SSH into the Pi
# Find the mount path of your secondary SSD
df -h | grep srv
# Note the path — it will look like /srv/dev-disk-by-uuid-<UUID>

# Create the Docker data directory on the SSD
sudo mkdir -p /srv/dev-disk-by-uuid-<PARITY-UUID>/docker

# Create or edit the Docker daemon config
sudo nano /etc/docker/daemon.json
```

Add this content:

```json
{
  "data-root": "/srv/dev-disk-by-uuid-<PARITY-UUID>/docker"
}
```

Restart Docker:

```bash
sudo systemctl restart docker
sudo systemctl status docker

# Verify the new data root
docker info | grep "Docker Root Dir"
# Should show the SSD path
```

---

## Step 3 — Install Portainer

Portainer provides a web UI for managing containers, viewing logs, and deploying Compose stacks.

```bash
# Create a volume for Portainer data
docker volume create portainer_data

# Run Portainer
docker run -d \
  --name portainer \
  --restart=always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

Access Portainer at `http://pi5-nas.local:9000`.

On first launch:
1. Create an admin username and password
2. Select **Get Started**
3. Click **local** environment
4. You're in — the Portainer dashboard loads

---

## Step 4 — Set Up a Shared Compose Directory

Store all your `docker-compose.yml` files on the NAS pool so they're included in backups:

```bash
sudo mkdir -p /srv/mergerfs/storage-pool/Docker/Compose
```

Use this directory for all compose files going forward. Each application gets its own subfolder:

```
/srv/mergerfs/storage-pool/Docker/Compose/
├── nextcloud/
│   └── docker-compose.yml
├── immich/
│   └── docker-compose.yml
└── homeassistant/
    └── docker-compose.yml
```

---

## Using Portainer for Compose Stacks

### Deploy a new stack

1. **Portainer → Stacks → + Add stack**
2. Name: `nextcloud` (or app name)
3. Paste or upload the `docker-compose.yml` content
4. Click **Deploy the stack**

### View container logs

1. **Portainer → Containers**
2. Click the container name
3. Click **Logs** — live, scrollable output

### Update a container to latest image

1. **Portainer → Containers** → select the container → **Stop**
2. **Images** → find the old image → **Pull** the latest tag
3. **Containers → + Add container** or redeploy the stack

---

## Useful Docker Commands

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# View container logs
docker logs <container-name>
docker logs -f <container-name>    # Follow / live tail

# Restart a container
docker restart <container-name>

# Enter a running container shell
docker exec -it <container-name> bash

# Pull latest image for a container
docker pull <image-name>:latest

# Remove unused images (free up space)
docker image prune -a

# Check disk usage by Docker
docker system df
```

---

## Keeping Containers Updated

Pull and redeploy containers monthly to get security patches:

```bash
# Pull latest versions of all running container images
docker compose -f /srv/mergerfs/storage-pool/Docker/Compose/nextcloud/docker-compose.yml pull
docker compose -f /srv/mergerfs/storage-pool/Docker/Compose/nextcloud/docker-compose.yml up -d
```

Or use Portainer's **Stack → Pull and redeploy** button.

---

**Next step:** [Nextcloud](05-NEXTCLOUD.md)
