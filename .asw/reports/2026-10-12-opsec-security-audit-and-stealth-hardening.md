# OPSEC & Host Hardening Assessment: Making the Machine Unreachable & Stealth

**Date**: 2026-10-12  
**Target Host**: Linux / Arch Linux (`pranc`)  
**Scope**: Host-level exposure, network reachability, local isolation, and stealth profile  
**Status**: Initial Audit Complete • Hardening Blueprint Defined

---

## 1. Executive Summary & Current Risk Posture

The primary objective is to make this PC **completely unreachable from the outside** (local Wi-Fi, LAN, and internet) while keeping all normal desktop workflows, browsers, and development tools functioning seamlessly.

A live, non-invasive system audit was performed. Here is the current posture:

| Surface | Current State | Risk Level | Finding |
|---|---|:---:|---|
| **Inbound Firewall** | Inactive (`nftables` / `iptables` off, `ufw` missing) | ⚠️ **HIGH** | Incoming connections from LAN are not blocked by default. Spotify is currently listening on `0.0.0.0`. |
| **Inbound Remote Access (SSH)** | Inactive (`sshd` off) | 🟢 **SAFE** | No SSH listening daemon exposed to the network. |
| **Physical Lock** | Active (`hypridle` locks at 120s) | 🟢 **SAFE** | Screen automatically locks with `hyprlock` after 2 minutes of idle. |
| **SSH Identity Storage** | Protected (`~/.ssh/id_ed25519` has passphrase, `0600`) | 🟢 **SAFE** | Private key cannot be used without entering the passphrase. |
| **Bluetooth Surface** | Powered off & non-discoverable | 🟢 **SAFE** | Bluetooth adapter is down and invisible to nearby RF scanners. |
| **Wi-Fi Hardware Tracking** | Default (Hardware MAC broadcast) | 🟡 **MEDIUM** | NetworkManager does not currently randomize the Wi-Fi MAC address when scanning/connecting. |
| **DNS Privacy** | Plaintext (8.8.8.8 / ISP DNS on port 53) | 🟡 **MEDIUM** | Domain names visited are visible to the local router and ISP. |
| **Local Daemons (Cool-Shell)** | Localhost only (`127.0.0.1` / Unix sockets) | 🟢 **SAFE** | God's Eye, AI Image Daemon, and Screen Lens are strictly local-bound. |

---

## 2. The 4-Pillar "Unreachable Host" Blueprint

### Pillar 1: Total Stealth Inbound Firewall (Drop Everything)
- **Goal**: Make the computer invisible to any network scanner (`nmap`, ping, automated botnets, other devices on public/dorm/home Wi-Fi).
- **Rule**:
  - `Default Incoming: DENY (DROP)`
  - `Default Outgoing: ALLOW`
- **Result**: You can browse the web, game, code, and download anything normally, but nobody on your Wi-Fi or the internet can initiate a connection to your laptop. To them, your IP address appears dead/powered off.

### Pillar 2: Wi-Fi Identity Masking (MAC Randomization)
- **Goal**: Prevent Wi-Fi access points (hotels, cafes, college campus, neighbors) from tracking your device across locations.
- **Mechanism**: Every time your Wi-Fi card scans or connects, it presents a freshly randomized hardware address.

### Pillar 3: Encrypted DNS (Prevent Browsing Snooping)
- **Goal**: Prevent your ISP or router admin from seeing which websites you open.
- **Mechanism**: Route DNS lookups over HTTPS (DoH) or TLS (DoT) via `systemd-resolved` or Cloudflare/Quad9 encrypted resolvers.

### Pillar 4: Localhost-Only Service Discipline
- **Goal**: Ensure no local development servers ever bind to `0.0.0.0` (all network cards).
- **Enforcement**: Cool-shell services (God's Eye, AI Studio daemon) are already bound strictly to `127.0.0.1` and `/tmp/*.sock`.
