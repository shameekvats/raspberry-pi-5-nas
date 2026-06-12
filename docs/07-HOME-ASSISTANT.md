# Home Assistant

Home Assistant (HA) is an open-source smart home platform. On this NAS it serves two purposes: smart home automation hub, and hardware monitoring / fan control for the NAS itself.

---

## Compose File

```bash
mkdir -p /srv/mergerfs/storage-pool/Docker/Compose/homeassistant
nano /srv/mergerfs/storage-pool/Docker/Compose/homeassistant/docker-compose.yml
```

```yaml
version: '3'

services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      TZ: Europe/Luxembourg
    volumes:
      - /srv/mergerfs/storage-pool/Docker/homeassistant:/config
      - /run/dbus:/run/dbus:ro
```

> `network_mode: host` is required for Home Assistant to discover local devices (mDNS, Bluetooth, Zigbee bridges, etc.) properly.
>
> `privileged: true` is required for GPIO access (fan control).

**Deploy:**

```bash
cd /srv/mergerfs/storage-pool/Docker/Compose/homeassistant
docker compose up -d
docker logs -f homeassistant
```

Access at `http://pi5-nas.local:8123` once logs show "Home Assistant started".

---

## First-Time Setup

1. Open `http://pi5-nas.local:8123`
2. Create an owner account
3. Complete the onboarding wizard — set location, units, and timezone
4. Home Assistant will auto-discover any compatible devices on the network

---

## GPIO Fan Control

The Radxa Penta SATA HAT Top Board includes a 4-pin PWM fan header. Home Assistant can control the fan via the Pi's GPIO pins, using CPU temperature as the trigger.

### Install HACS (optional but recommended)

HACS (Home Assistant Community Store) extends HA with community integrations. Install via the official guide: [hacs.xyz](https://hacs.xyz/docs/use/download/download/)

### Enable GPIO Integration

In `configuration.yaml` (accessible via **Settings → System → Edit configuration.yaml** or SSH at `/srv/mergerfs/storage-pool/Docker/homeassistant/configuration.yaml`):

```yaml
# Raspberry Pi GPIO
rpi_gpio:
  # No explicit config needed — auto-detected

# CPU temperature sensor
sensor:
  - platform: command_line
    name: "CPU Temperature"
    command: "cat /sys/class/thermal/thermal_zone0/temp"
    unit_of_measurement: "°C"
    value_template: "{{ (value | int / 1000) | round(1) }}"
    scan_interval: 30
```

### Fan Control Automation

In **Settings → Automations → + Create Automation**, or paste into `automations.yaml`:

```yaml
- alias: "NAS Fan On — CPU above 55°C"
  trigger:
    platform: numeric_state
    entity_id: sensor.cpu_temperature
    above: 55
  action:
    service: rpi_gpio.write_output
    data:
      pin: 14        # Adjust to the GPIO pin connected to your fan header
      value: true

- alias: "NAS Fan Off — CPU below 50°C"
  trigger:
    platform: numeric_state
    entity_id: sensor.cpu_temperature
    below: 50
  action:
    service: rpi_gpio.write_output
    data:
      pin: 14
      value: false
```

> Check the Radxa Penta SATA HAT Top Board documentation for the correct GPIO pin number for the fan header on your specific board revision.

Restart Home Assistant after editing configuration files:

```bash
docker restart homeassistant
```

---

## NAS Monitoring Dashboard

Create a dashboard card in Home Assistant to monitor the NAS at a glance:

1. **Settings → Dashboards → + Add Dashboard**
2. Name: `NAS Monitor`
3. Add cards:
   - **Gauge** card — CPU Temperature (sensor.cpu_temperature)
   - **History Graph** — temperature over last 24 hours
   - **Entity** cards — any drive temperature sensors you add

### Add Drive Temperature Sensors

If you install the `smartmontools` command-line integration:

```yaml
sensor:
  - platform: command_line
    name: "NAS Drive 1 Temp"
    command: "sudo smartctl -A /dev/sda | grep Temperature_Celsius | awk '{print $10}'"
    unit_of_measurement: "°C"
    scan_interval: 300

  - platform: command_line
    name: "NAS Drive 2 Temp"
    command: "sudo smartctl -A /dev/sdb | grep Temperature_Celsius | awk '{print $10}'"
    unit_of_measurement: "°C"
    scan_interval: 300
```

> The HA container needs the `smartctl` binary. Either install it in the container or use a shell sensor that calls `smartctl` via SSH from within the container.

---

## Mobile App

1. Install **Home Assistant** from the App Store or Google Play
2. The app auto-discovers Home Assistant instances on the local network
3. For remote access (outside home), add your Tailscale address:
   - **Settings → Companion App → Servers → + Add Server**
   - URL: `http://<TAILSCALE_IP>:8123`

---

## Useful Configuration Files

All Home Assistant config lives at:
```
/srv/mergerfs/storage-pool/Docker/homeassistant/
├── configuration.yaml    ← Main config
├── automations.yaml      ← Automations
├── scripts.yaml          ← Scripts
├── scenes.yaml           ← Scenes
└── .storage/             ← UI-configured entities (do not edit manually)
```

---

## Backing Up Home Assistant Config

Home Assistant config is in the NAS pool (`Docker/homeassistant/`) and will be included in your regular backup strategy. Additionally, HA has a built-in backup tool:

**Settings → System → Backups → Create Backup**

Download the backup file and store it off the NAS (e.g. your Mac).

---

**Next step:** [Tailscale — Remote Access](08-TAILSCALE.md)
