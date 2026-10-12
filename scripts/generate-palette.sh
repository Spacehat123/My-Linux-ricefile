#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin"

wallpaper=${1:-}
if [[ -z "$wallpaper" ]]; then
  if [[ -s "$HOME/.local/state/vyeos/current-wallpaper" ]]; then
    wallpaper=$(cat "$HOME/.local/state/vyeos/current-wallpaper")
  fi
fi

if [[ -z "$wallpaper" || ! -f "$wallpaper" ]]; then
  echo "Error: valid wallpaper required" >&2
  exit 1
fi

theme_dir="$HOME/.config/vyeos/themes"
state_dir="$HOME/.local/state/vyeos"
mkdir -p "$theme_dir" "$state_dir"

# Generate M3 palette via matugen
matugen_json=$(matugen image "$wallpaper" -j hex --source-color-index 0)

theme_json=$(echo "$matugen_json" | jq '{
  name: "Material You",
  slug: "material",
  appearance: "dark",
  colors: {
    bg_dim: ((.colors.surface_container_lowest // .colors.background).default.color),
    bg0: ((.colors.surface_container_low // .colors.surface).default.color),
    bg1: .colors.surface_container.default.color,
    bg2: .colors.surface_container_high.default.color,
    bg3: .colors.surface_container_highest.default.color,
    bg4: .colors.surface_variant.default.color,
    primary_container: .colors.primary_container.default.color,
    secondary_container: .colors.secondary_container.default.color,
    foreground: .colors.on_surface.default.color,
    muted: .colors.on_surface_variant.default.color,
    muted_dark: .colors.outline.default.color,
    red: .colors.error.default.color,
    yellow: .colors.tertiary.default.color,
    green: "#9bc892",
    primary: .colors.primary.default.color,
    blue: .colors.secondary.default.color,
    aqua: .colors.inverse_primary.default.color,
    orange: .colors.error_container.default.color,
    purple: .colors.secondary_fixed.default.color
  }
}')

echo "$theme_json" > "$theme_dir/material.json"
echo "material" > "$state_dir/current-theme"

# Update Hyprland active border colors to match Material You primary & container
primary=$(echo "$theme_json" | jq -r '.colors.primary')
primary_container=$(echo "$theme_json" | jq -r '.colors.primary_container')
p_clean="${primary//\#/}"
pc_clean="${primary_container//\#/}"

if command -v hyprctl >/dev/null; then
  hyprctl keyword general:col.active_border "rgb($p_clean) rgb($pc_clean) 45deg" >/dev/null 2>&1 || true
fi

# Notify Cool-Shell to reload theme
qs -c cool-shell ipc call theme reload >/dev/null 2>&1 || true
qs -c cool-shell ipc call island showTransient "🎨 Material You palette active" 2500 >/dev/null 2>&1 || true
echo "SUCCESS: Material You theme generated and applied from $wallpaper"
