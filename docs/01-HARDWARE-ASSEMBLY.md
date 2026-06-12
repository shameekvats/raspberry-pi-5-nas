# Hardware Assembly

## Parts List

### Required

| Part | Notes |
|---|---|
| Raspberry Pi 5 (8GB or 16GB) | 16GB recommended for running multiple Docker containers |
| Raspberry Pi 5 Active Cooler | Official cooler — important for sustained load |
| Radxa Penta SATA HAT | Adds 5× 2.5" SATA ports via PCIe |
| Radxa Penta SATA HAT Top Board | Required — provides GPIO connection and fan header |
| **GPIO extension cable/pins (40-pin)** | **Required to solve Active Cooler conflict — see below** |
| 2–5× NAS-grade 2.5" SATA SSD | WD Red SA500, Seagate IronWolf 125, or Samsung 870 EVO |
| 12V 5A+ barrel jack power supply (5.5×2.5mm) | Powers HAT and Pi via GPIO — 6A recommended |
| MicroSD card (32GB+, A2 rated) | OS only — SanDisk Extreme or Samsung EVO Select |
| Cat6 Ethernet cable | Wired connection strongly recommended over WiFi |

### Optional but Recommended

| Part | Notes |
|---|---|
| 80mm PWM fan (4-pin, 5V or 12V) | Mounts on Top Board fan header — improves SSD cooling |
| USB-C power supply (27W / 5A) | Additional Pi power if HAT supply is insufficient |
| Case with ventilation | 3D printable designs available |

---

## ⚠️ GPIO Interference — Critical Note

The **Raspberry Pi 5 Active Cooler** uses a 4-pin power connector that sits directly where the **Penta HAT Top Board** needs to connect to the GPIO header. Mounting the Top Board directly onto the Pi will either physically conflict or leave the cooler cable disconnected.

**Solution: GPIO extension cable**

Insert a 40-pin GPIO extension between the Pi and the Top Board. This raises the Top Board just enough to clear the cooler connector without modifying either component.

**Correct stack order (bottom to top):**

```
Raspberry Pi 5
    (Active Cooler installed on top of Pi)
        ↓
GPIO Extension Cable / Riser Pins
        ↓
Radxa Penta SATA HAT Top Board
        ↓
Radxa Penta SATA HAT (connected via FFC cable)
```

---

## Assembly Steps

### Step 1 — Install Active Cooler on Pi

1. Align the cooler with the CPU and GPIO header cutout
2. Connect the cooler's 4-pin power cable to the Pi's fan connector
3. Secure with the provided screws (finger-tight)
4. **Do not power on yet**

### Step 2 — Attach GPIO Extension

1. Align the 40-pin GPIO extension with the Pi's GPIO header
2. Press down firmly and evenly — ensure all 40 pins make contact
3. The extension should sit level and stable
4. Verify the Active Cooler's power connector now has clearance above it

### Step 3 — Mount Penta HAT Top Board

1. Align the Top Board's 40-pin connector with the GPIO extension (not directly with the Pi)
2. Press down gently but firmly across all pins
3. The Top Board should clear the Active Cooler connector
4. Confirm stability — no wobble

### Step 4 — Connect Top Board to Penta HAT (FFC Cable)

1. Locate the FFC (flat flex cable) that came with the HAT
2. Unlock the FFC connector on the Top Board (lift the small locking tab)
3. Insert the cable — **contacts facing down** toward the PCB — until it stops
4. Lock the connector (press the tab down)
5. Repeat on the Penta HAT side
6. The cable should lie flat with no sharp bends or twists

### Step 5 — Install Fan on Top Board (Optional)

1. Locate the 4-pin PWM fan header on the Top Board
2. Connect the fan cable — note correct polarity
3. Position the fan to pull air upward, away from the drives
4. Secure with screws or zip ties

### Step 6 — Install SSDs

Assign drives to ports before installing — label them with tape so you can identify them later.

**Recommended port assignment:**

```
Port 0 (SATA0): Primary NAS drive #1
Port 1 (SATA1): Primary NAS drive #2
Port 2 (SATA2): Primary NAS drive #3
Port 3 (SATA3): Secondary/consumer SSD (Docker + backups)
Port 4 (SATA4): Empty — future expansion
```

For each drive:
1. Slide into the SATA connector firmly until fully seated
2. Secure with mounting screws if provided
3. Label the drive slot

### Step 7 — Power Connections

1. Connect the 12V barrel jack to the Penta HAT
2. The HAT powers both itself (and the connected SSDs) **and** the Pi via GPIO — a single supply is sufficient
3. If you experience instability, also connect the official USB-C supply to the Pi
4. Connect the Ethernet cable to the Pi's RJ45 port

### Step 8 — Pre-Power Checklist

Before applying power, verify:

- [ ] All SSDs fully seated
- [ ] FFC cable locked at both ends
- [ ] GPIO extension and Top Board fully pressed in
- [ ] Active Cooler power cable connected
- [ ] Fan connected (if installed)
- [ ] MicroSD card inserted (flash it first — see [OMV guide](02-OPENMEDIAVAULT.md))
- [ ] Ethernet cable connected to router

---

## First Power-On

**Power sequence:**
1. Connect 12V power to Penta HAT
2. Watch for:
   - Green LED on Penta HAT
   - Red/green LED on Pi
   - Active Cooler spinning
   - Optional fan spinning
3. Wait 60–90 seconds for boot
4. No smoke, no unusual sounds — SSDs are silent

---

## Verify Drives Are Detected

After SSH connection (see [OMV guide](02-OPENMEDIAVAULT.md)):

```bash
lsblk
```

Expected output:
```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
mmcblk0     179:0    0 119.1G  0 disk   ← SD card
sda           8:0    0 931.5G  0 disk   ← Drive 1
sdb           8:16   0 931.5G  0 disk   ← Drive 2
sdc           8:32   0 931.5G  0 disk   ← Drive 3
sdd           8:48   0 447.1G  0 disk   ← Drive 4
```

If drives are missing, reseat the FFC cable and check power — the most common causes are a loose FFC connection or insufficient power.

```bash
# Check SMART identity for each drive
sudo apt install smartmontools -y
sudo smartctl -i /dev/sda
sudo smartctl -i /dev/sdb
sudo smartctl -i /dev/sdc
sudo smartctl -i /dev/sdd
```

Record the model and serial number of each drive and which `/dev/sdX` it maps to. The mapping can change after reboots if drives are not identified by UUID.
