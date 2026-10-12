# God's Eye View Setup & Operational Guide

**Date**: 2026-10-12  
**Status**: Successfully Installed & Verified  
**Installation Location**: `/home/pranc/Desktop/gods-eye-view`  

---

## 1. Executive Summary

**God's Eye View** (`bilawalsidhu/gods-eye-view`) has been cloned, configured, and verified in `/home/pranc/Desktop/gods-eye-view`. It is a real-time browser-based 3D geospatial intelligence globe and simulator integrating live public tracking feeds for aircraft, ships, satellites, earthquakes, wildfires, and weather.

---

## 2. Environment Configuration

* **Runtime**: Node.js `v24.21.0` (installed via `fnm` and linked to `~/.local/bin/node`)
* **Package Manager**: npm `11.19.0` (linked to `~/.local/bin/npm`)
* **Dependencies**: 171 packages installed via `npm ci`
* **Setup Doctor**: `npm run doctor` verified (0 errors):
  * Node: 24.21.0 LTS supported
  * Satellite Basemap: Esri World Imagery (keyless)
  * Flight Transponders: OpenSky anonymous live stream
  * Space Missions: Launch Library 2 public access
  * Terrain: Keyless 3D global elevation
* **Dev Server**: Vite v6.4.3 verified on `http://localhost:4173` (HTTP 200 OK)
* **Launcher**: Created executable launcher [`/home/pranc/Desktop/gods-eye-view/start.sh`](file:///home/pranc/Desktop/gods-eye-view/start.sh)

---

## 3. How to Launch and Use

### Starting the Globe
```bash
cd ~/Desktop/gods-eye-view
./start.sh
```
Open your browser to:
👉 **`http://localhost:4173`**

### Features Available Immediately (Zero API Keys Needed)
* **Live Flight Tracking & Cockpit Cam**: Real-time ADS-B transponders with 3D aircraft models and chase camera view.
* **Active Satellite Orbits**: Real-time satellite positions and ground footprints.
* **Seismic Activity**: Live earthquake telemetry and depth visualization.
* **Environmental & Weather**: Wind forecasts (GFS/ECMWF), live radar, satellite cloud layers, and hurricane/cyclone paths.
* **Tactical Visual Filters**: Military HUD overlays, FLIR (thermal infrared), Night-Vision (NVG), CRT scanlines, and high-contrast Noir.

### Optional Upgrades (via `.env` or in-app "Power Up" panel)
* **Google Photorealistic 3D Tiles / Cesium ion**: Ultra-high-resolution 3D city buildings and photogrammetry.
* **AISStream**: Live oceanic vessel and cargo ship tracking.
* **NASA FIRMS**: Live active wildfire hotspots.
* **OpenAI Realtime Voice**: Hands-free voice commands to navigate the planet.
