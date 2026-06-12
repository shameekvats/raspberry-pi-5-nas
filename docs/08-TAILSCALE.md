# Tailscale — Secure Remote Access

Tailscale is a zero-config VPN built on WireGuard. It connects your devices into a private network, giving you access to the NAS from anywhere without opening any ports on your router.

**Why Tailscale instead of port forwarding:**
- No ports exposed to the internet
- No dynamic DNS needed
- Works through NAT and firewalls transparently
- Each device gets a stable private IP (100.x.x.x range)
- Free tier supports up to 100 devices

---

## Step 1 — Create a Tailscale Account

Sign up at [tailscale.com](https://tailscale.com) — free for personal use.

---

## Step 2 — Install Tailscale on the Pi

```bash
# SSH into the Pi
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale and authenticate
sudo tailscale up

# A URL will be shown — open it in a browser to authenticate
# After approving, the Pi joins your Tailscale network
```

Check the assigned Tailscale IP:

```bash
tailscale ip -4
# Returns something like 100.x.x.x — note this address
```

Check status:

```bash
tailscale status
# Shows all devices in your Tailscale network
```

Enable Tailscale to start on boot (it does this automatically after install):

```bash
sudo systemctl enable tailscaled
sudo systemctl status tailscaled
```

---

## Step 3 — Install Tailscale on Your Other Devices

Install on every device you want to use for remote access:

- **macOS / Windows / Linux:** [tailscale.com/download](https://tailscale.com/download)
- **iOS / Android:** App Store / Google Play — search "Tailscale"

Log in with the same account on all devices. They automatically join the same private network.

---

## Step 4 — Access the NAS Remotely

Once all devices are on Tailscale, use the Pi's Tailscale IP instead of the local hostname:

| Service | Local URL | Remote URL (Tailscale) |
|---|---|---|
| OMV dashboard | `http://pi5-nas.local` | `http://100.x.x.x` |
| Nextcloud | `http://pi5-nas.local:8080` | `http://100.x.x.x:8080` |
| Immich | `http://pi5-nas.local:2283` | `http://100.x.x.x:2283` |
| Home Assistant | `http://pi5-nas.local:8123` | `http://100.x.x.x:8123` |
| SSH | `ssh user@pi5-nas.local` | `ssh user@100.x.x.x` |

The Tailscale IP is stable — it won't change even if the Pi gets a different local IP from your router.

---

## Step 5 — Add Tailscale IP as Trusted Domain in Nextcloud

Nextcloud rejects requests from unknown addresses. Add the Tailscale IP to trusted domains:

```bash
docker exec -it nextcloud bash
php occ config:system:set trusted_domains 3 --value="100.x.x.x"
exit
```

Or edit `config/config.php` in the nextcloud-app volume directly.

---

## Step 6 — Configure Immich Mobile App for Remote Access

In the Immich mobile app:

1. **Account → Server** — add a second server entry
2. URL: `http://100.x.x.x:2283`
3. The app uses the local server when on WiFi and the Tailscale address when on cellular

---

## Step 7 — Configure Home Assistant Mobile App for Remote Access

In the Home Assistant companion app:

1. **Settings → Companion App → Manage Servers → + Add Server**
2. URL: `http://100.x.x.x:8123`
3. The app automatically switches between local and remote depending on network

---

## DHCP Reservation (Recommended)

To ensure the Pi always gets the same local IP from your router (so bookmarks and Samba mounts don't break after a reboot):

1. Log into your router admin panel (usually `http://192.168.1.1`)
2. Find **DHCP Reservations**, **Static Leases**, or **Address Reservation**
3. Find the Pi in the connected devices list (labeled `pi5-nas`)
4. Bind its MAC address to its current IP

This keeps the local IP stable without configuring a static IP on the Pi itself — which would bypass DHCP and risk breaking network config if OMV regenerates it.

---

## Tailscale Quick Reference

```bash
# Check status and connected devices
tailscale status

# Get the Pi's Tailscale IP
tailscale ip -4

# Re-authenticate (if session expires)
sudo tailscale up

# Disconnect from Tailscale (Pi stays on local network)
sudo tailscale down

# Reconnect
sudo tailscale up
```

---

**Next step:** [Backups](09-BACKUPS.md)
