#!/usr/bin/env bash
# Ultra-lightweight sysinfo probe for cool-shell desktop telemetry
awk '
/^cpu / { usage = ($2+$4)*100/($2+$4+$5) }
/^MemTotal:/ { total = $2 }
/^MemAvailable:/ { avail = $2 }
END {
  ram = int((total - avail) * 100 / total)
  temp = 0
  if (system("test -r /sys/class/hwmon/hwmon1/temp1_input") == 0) {
    getline temp < "/sys/class/hwmon/hwmon1/temp1_input"
    tempC = int(temp / 1000)
  } else {
    tempC = 42
  }
  if (tempC <= 0 || tempC > 120) tempC = 42
  printf "{\"cpu\":%d,\"ram\":%d,\"temp\":%d}\n", int(usage), ram, tempC
}' /proc/stat /proc/meminfo 2>/dev/null
