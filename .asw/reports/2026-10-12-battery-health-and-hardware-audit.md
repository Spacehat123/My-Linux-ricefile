# Battery Health & Hardware Telemetry Audit

**Date**: 2026-10-12  
**Target Hardware**: Acer Aspire A715-42G (BIOS V1.10)  
**Battery Identifier**: `BAT1` (`/sys/class/power_supply/BAT1`)  
**Status**: COMPLETED & VERIFIED

---

## 1. Executive Summary

A comprehensive hardware telemetry and state inspection of the primary battery (`BAT1`) was conducted using direct Linux sysfs kernel interfaces (`/sys/class/power_supply/BAT1/`) and Freedesktop `UPower` daemon metrics.

### Key Metrics Overview
* **Overall Battery Health**: **`67.87%`** (Fair / Moderate Degradation)
* **Wear Level / Capacity Loss**: **`32.13%`**
* **Original Design Capacity**: **`48.00 Wh`** (`4,267 mAh` @ `11.25 V`)
* **Current Maximum Usable Capacity**: **`32.58 Wh`** (`2,896 mAh`)
* **Current Charge State**: **`98%`** (`32.03 Wh`, Charging / AC Connected)
* **Current Draw / Charge Rate**: **`3.43 W`** (Trickle stage near saturation)
* **Estimated Time to 100%**: **`~9.6 minutes`**

---

## 2. Hardware & Manufacturer Specifications

| Property | Sysfs Metric | Evaluated Value | Notes |
| :--- | :--- | :--- | :--- |
| **Laptop Chassis** | `/sys/class/dmi/id/product_name` | **Acer Aspire A715-42G** | AMD Ryzen + NVIDIA Platform |
| **Battery Model** | `model_name` | **AP18C8K** | Standard OEM 3-Cell Li-ion pack |
| **Manufacturer** | `manufacturer` | **LGC (LG Chem)** | Tier-1 cell provider |
| **Serial Number** | `serial_number` | **59389** | Factory hardware ID |
| **Technology** | `technology` | **Lithium-Ion (Li-ion)** | 3S configuration |
| **Nominal Voltage** | `voltage_min_design` | **11.25 V** | 3.75 V/cell nominal |
| **Current Operating Voltage** | `voltage_now` | **12.673 V** | ~4.22 V/cell (normal for 98% charge) |
| **Cycle Count** | `cycle_count` | *0 / Unreported* | Acer ACPI table omits hardware cycle counter |

---

## 3. Capacity & Wear Analysis

The battery pack has undergone typical lithium-ion aging since installation:

$$\text{Health Percentage} = \frac{\text{Current Full Capacity}}{\text{Design Full Capacity}} \times 100\% = \frac{32.58\text{ Wh}}{48.00\text{ Wh}} \times 100\% = \mathbf{67.87\%}$$

$$\text{Total Wear Level} = 100\% - 67.87\% = \mathbf{32.13\%}$$

### Interpretation
1. **Capacity Retained**: At `32.58 Wh`, the pack holds approximately two-thirds of its factory energy reserve.
2. **Estimated Real-World Runtime**:
   - Under lightweight desktop load (`5 W - 8 W` average consumption): **~4 to 6 hours**.
   - Under medium development / browsing load (`10 W - 15 W`): **~2 to 3.2 hours**.
   - Under heavy compilation or GPU utilization (`25 W - 45 W`): **~40 to 75 minutes**.
3. **Internal Cell Health**:
   - The cell voltage at 98% is `12.673 V`, indicating balanced charging across the 3 internal cells (~4.22V per series cell) without premature voltage sag or abrupt cutoff.

---

## 4. Recommendations for Longevity

1. **Avoid Frequent Deep Discharges**:
   - Lithium-ion cells experience the most electrochemical stress below 15% and above 85% state of charge (SoC). Recharging when reaching 20-30% rather than 0% preserves remaining cell cycle life.
2. **Heat Management**:
   - Because the Aspire A715-42G houses dedicated graphics, elevated chassis temperatures degrade battery cathode materials faster. Keep fan vents clear during intense workloads.
3. **Cool-Shell Feather Mode**:
   - When on battery power, activate **Feather Mode** (`The Feather` in Control Center / `scripts/feather-mode.py`) to throttle non-essential background processes, reduce compositor refresh demand, and maximize battery runtime.
