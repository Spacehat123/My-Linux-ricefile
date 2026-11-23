#!/usr/bin/env bash
# Ultra-lightweight sysinfo probe for cool-shell desktop telemetry

# Read initial CPU ticks from /proc/stat
read -r _ u1 n1 s1 i1 w1 irq1 s_irq1 st1 _ < /proc/stat
total1=$((u1 + n1 + s1 + i1 + w1 + irq1 + s_irq1 + st1))
idle1=$((i1 + w1))

# Read memory info while preparing for delta measurement
mem_total=0
mem_avail=0
while read -r key val _; do
    case "$key" in
        MemTotal:) mem_total=$val ;;
        MemAvailable:) mem_avail=$val ;;
    esac
    [ "$mem_total" -gt 0 ] && [ "$mem_avail" -gt 0 ] && break
done < /proc/meminfo

# Delta interval for instantaneous CPU calculation
sleep 0.1

# Read second CPU ticks
read -r _ u2 n2 s2 i2 w2 irq2 s_irq2 st2 _ < /proc/stat
total2=$((u2 + n2 + s2 + i2 + w2 + irq2 + s_irq2 + st2))
idle2=$((i2 + w2))

dt=$((total2 - total1))
di=$((idle2 - idle1))

if [ "$dt" -gt 0 ]; then
    cpu_usage=$(( (dt - di) * 100 / dt ))
else
    cpu_usage=0
fi

[ "$cpu_usage" -lt 0 ] && cpu_usage=0
[ "$cpu_usage" -gt 100 ] && cpu_usage=100

if [ "$mem_total" -gt 0 ]; then
    ram_usage=$(( (mem_total - mem_avail) * 100 / mem_total ))
else
    ram_usage=0
fi

# Read temperature from available hwmon sensor
tempC=42
for tf in /sys/class/hwmon/hwmon*/temp1_input; do
    if [ -r "$tf" ]; then
        read -r raw_temp < "$tf"
        if [ -n "$raw_temp" ] && [ "$raw_temp" -gt 0 ]; then
            tempC=$((raw_temp / 1000))
            break
        fi
    fi
done

[ "$tempC" -le 0 ] || [ "$tempC" -gt 120 ] && tempC=42

# Read GPU busy percent from available card (safely handling card0, card1, and card*)
gpu_busy=0
for gf in /sys/class/drm/card1/device/gpu_busy_percent /sys/class/drm/card0/device/gpu_busy_percent /sys/class/drm/card*/device/gpu_busy_percent; do
    if [ -r "$gf" ]; then
        read -r raw_gpu < "$gf"
        if [ -n "$raw_gpu" ]; then
            gpu_busy=$raw_gpu
            break
        fi
    fi
done

printf '{"cpu":%d,"ram":%d,"temp":%d,"gpu":%d}\n' "$cpu_usage" "$ram_usage" "$tempC" "$gpu_busy"
