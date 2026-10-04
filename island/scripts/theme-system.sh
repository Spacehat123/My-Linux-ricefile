#!/usr/bin/env bash
set -euo pipefail

# cool-shell adaptation: jq lives in ~/.local/bin (no sudo on this box);
# ensure it is on PATH so Quickshell-launched processes find it regardless
# of the environment the compositor was started with.
command -v jq >/dev/null 2>&1 || [[ -x $HOME/.local/bin/jq ]] && export PATH="$HOME/.local/bin:$PATH"
command -v jq >/dev/null 2>&1 || { printf 'theme-system: jq is required but not installed\n' >&2; exit 1; }

theme_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/vyeos/themes
cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/vyeos/theme
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/vyeos

# This setup deliberately uses ~/Pictures/Wallpapers. xdg-user-dir may resolve
# PICTURES to $HOME when XDG user directories have not been configured.
pictures_dir=${XDG_PICTURES_DIR:-"$HOME/Pictures"}
wallpaper_root=$pictures_dir/Wallpapers
live_wallpaper_dir=$wallpaper_root/live
thumbnail_cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/cool-shell/thumbnails
sddm_cache_dir=${VYEOS_SDDM_CACHE_DIR:-/var/cache/vyeos-sddm}

die() {
  printf 'theme-system: %s\n' "$*" >&2
  exit 1
}

theme_file() {
  local slug=$1
  [[ $slug =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid theme name: $slug"
  [[ -f $theme_dir/$slug.json ]] || die "unknown theme: $slug"
  printf '%s\n' "$theme_dir/$slug.json"
}

current_theme() {
  local slug=everforest
  if [[ -s $state_dir/current-theme ]]; then
    IFS= read -r slug < "$state_dir/current-theme"
  fi
  if [[ ! -f $theme_dir/$slug.json ]]; then
    slug=everforest
  fi
  printf '%s\n' "$slug"
}

list_themes() {
  jq -s 'map({name, slug, appearance, colors}) | sort_by(.name)' "$theme_dir"/*.json
}

is_video_file() {
  local file=$1
  case "${file,,}" in
    *.mp4|*.webm|*.mkv|*.mov) return 0 ;;
    *) return 1 ;;
  esac
}

get_video_thumbnail() {
  local video_path=$1
  mkdir -p "$thumbnail_cache_dir"
  local mtime size hash thumb_path
  mtime=$(stat -c '%Y' "$video_path" 2>/dev/null || date +%s)
  size=$(stat -c '%s' "$video_path" 2>/dev/null || echo 0)
  hash=$(printf '%s:%s:%s' "$video_path" "$mtime" "$size" | md5sum | cut -d' ' -f1)
  thumb_path="$thumbnail_cache_dir/${hash}.jpg"
  if [[ ! -s "$thumb_path" ]] && command -v ffmpeg >/dev/null; then
    ffmpeg -loglevel error -y -ss 00:00:01 -i "$video_path" -vf "scale=480:-1" -update 1 -frames:v 1 -q:v 3 "$thumb_path" >/dev/null 2>&1 || true
  fi
  if [[ -s "$thumb_path" ]]; then
    printf '%s' "$thumb_path"
  else
    printf '%s' "$video_path"
  fi
}

list_wallpapers() {
  local slug=${1:-$(current_theme)} directory path first=true
  theme_file "$slug" >/dev/null
  directory=$wallpaper_root/$slug
  mkdir -p "$live_wallpaper_dir"

  local search_dirs=()
  [[ -d "$directory" ]] && search_dirs+=("$directory")
  [[ -d "$live_wallpaper_dir" && "$directory" != "$live_wallpaper_dir" ]] && search_dirs+=("$live_wallpaper_dir")

  printf '['
  if [[ ${#search_dirs[@]} -gt 0 ]]; then
    while IFS= read -r -d '' path; do
      $first || printf ','
      first=false
      path=$(realpath -- "$path")
      local is_video=false thumb="$path"
      if is_video_file "$path"; then
        is_video=true
        thumb=$(get_video_thumbnail "$path")
      fi
      jq -cn \
        --arg path "$path" \
        --arg name "$(basename "$path")" \
        --arg thumb "$thumb" \
        --argjson isVideo "$is_video" \
        '{name:$name,path:$path,thumbnail:$thumb,isVideo:$isVideo}'
    done < <(find "${search_dirs[@]}" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) -print0 | sort -z -u)
  fi
  printf ']\n'
}

open_wallpaper_folder() {
  local slug=${1:-$(current_theme)} directory
  theme_file "$slug" >/dev/null
  directory=$wallpaper_root/$slug
  mkdir -p "$directory"
  xdg-open "$directory" >/dev/null 2>&1
}

open_live_wallpaper_folder() {
  mkdir -p "$live_wallpaper_dir"
  xdg-open "$live_wallpaper_dir" >/dev/null 2>&1
}

wallpaper_for_theme() {
  local slug=$1 directory saved=
  directory=$wallpaper_root/$slug
  if [[ -s $state_dir/wallpapers/$slug ]]; then
    IFS= read -r saved < "$state_dir/wallpapers/$slug"
  elif [[ -s $state_dir/current-wallpaper ]]; then
    IFS= read -r saved < "$state_dir/current-wallpaper"
  fi
  if [[ -n $saved && -f $saved ]]; then
    local real_saved
    real_saved=$(realpath -- "$saved")
    if [[ $real_saved == "$(realpath -m -- "$directory")/"* || $real_saved == "$(realpath -m -- "$live_wallpaper_dir")/"* ]]; then
      printf '%s\n' "$real_saved"
      return
    fi
  fi
  find "$directory" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' \) -print -quit 2>/dev/null || true
}


write_sddm_theme() {
  local file=$1 output=$2 use_wallpaper=$3
  local bg_dim bg0 bg1 bg2 bg3 foreground primary yellow red
  bg_dim=$(jq -er '.colors.bg_dim' "$file")
  bg0=$(jq -er '.colors.bg0' "$file")
  bg1=$(jq -er '.colors.bg1' "$file")
  bg2=$(jq -er '.colors.bg2' "$file")
  bg3=$(jq -er '.colors.bg3' "$file")
  foreground=$(jq -er '.colors.foreground' "$file")
  primary=$(jq -er '.colors.primary' "$file")
  yellow=$(jq -er '.colors.yellow' "$file")
  red=$(jq -er '.colors.red' "$file")

  {
    printf '[LockScreen]\nbackground = "vyeos-wallpaper.jpg"\nuse-background-color = %s\nbackground-color = "%s"\nblur = 28\nbrightness = -0.12\n\n' "$([[ $use_wallpaper == true ]] && printf false || printf true)" "$bg0"
    printf '[LockScreen.Clock]\ncolor = "%s"\nfont-size = 84\n\n[LockScreen.Date]\ncolor = "%s"\nfont-size = 17\n\n' "$foreground" "$foreground"
    printf '[LockScreen.Message]\ncolor = "%s"\nfont-size = 14\n\n' "$foreground"
    printf '[LoginScreen]\nbackground = "vyeos-wallpaper.jpg"\nuse-background-color = %s\nbackground-color = "%s"\nblur = 28\nbrightness = -0.12\n\n' "$([[ $use_wallpaper == true ]] && printf false || printf true)" "$bg0"
    printf '[LoginScreen.LoginArea.Avatar]\nactive-border-color = "%s"\ninactive-border-color = "%s"\n\n' "$primary" "$primary"
    printf '[LoginScreen.LoginArea.Username]\ncolor = "%s"\nfont-size = 19\n\n' "$foreground"
    printf '[LoginScreen.LoginArea.PasswordInput]\ncontent-color = "%s"\nbackground-color = "%s"\nborder-color = "%s"\nfont-size = 14\n\n' "$foreground" "$bg1" "$primary"
    printf '[LoginScreen.LoginArea.LoginButton]\nbackground-color = "%s"\nactive-background-color = "%s"\ncontent-color = "%s"\nactive-content-color = "%s"\nborder-color = "%s"\nfont-size = 14\n\n' "$bg1" "$primary" "$primary" "$bg_dim" "$primary"
    printf '[LoginScreen.LoginArea.Spinner]\ncolor = "%s"\nfont-size = 17\n\n' "$foreground"
    printf '[LoginScreen.LoginArea.WarningMessage]\nnormal-color = "%s"\nwarning-color = "%s"\nerror-color = "%s"\nfont-size = 13\n\n' "$foreground" "$yellow" "$red"
    printf '[LoginScreen.MenuArea.Popups]\nbackground-color = "%s"\nactive-option-background-color = "%s"\ncontent-color = "%s"\nactive-content-color = "%s"\nborder-color = "%s"\nfont-size = 13\n\n' "$bg1" "$bg2" "$foreground" "$primary" "$primary"
    local section
    for section in Session Layout Keyboard Power; do
      printf '[LoginScreen.MenuArea.%s]\nbackground-color = "%s"\ncontent-color = "%s"\nactive-content-color = "%s"\nfont-size = 12\n\n' "$section" "$primary" "$foreground" "$bg_dim"
    done
    printf '[LoginScreen.VirtualKeyboard]\nbackground-color = "%s"\nkey-content-color = "%s"\nkey-color = "%s"\nkey-active-background-color = "%s"\nselection-background-color = "%s"\nselection-content-color = "%s"\nprimary-color = "%s"\nborder-color = "%s"\n\n' "$bg1" "$foreground" "$bg2" "$primary" "$primary" "$bg_dim" "$primary" "$bg3"
    printf '[Tooltips]\ncontent-color = "%s"\nbackground-color = "%s"\nfont-size = 13\n' "$foreground" "$bg1"
  } > "$output"
}

sync_sddm_theme() {
  local file=$1 slug wallpaper config_tmp wallpaper_tmp source_key cached_source= use_wallpaper=false
  [[ -d $sddm_cache_dir && -w $sddm_cache_dir ]] || return 0
  slug=$(jq -er '.slug' "$file")
  wallpaper=$(wallpaper_for_theme "$slug")

  if [[ -n $wallpaper && -f $wallpaper ]] && command -v ffmpeg >/dev/null; then
    source_key="$(realpath -- "$wallpaper")|$(stat -c '%s:%Y' -- "$wallpaper")"
    [[ ! -s $sddm_cache_dir/wallpaper-source ]] || IFS= read -r cached_source < "$sddm_cache_dir/wallpaper-source"
    if [[ $source_key == "$cached_source" && -s $sddm_cache_dir/vyeos-wallpaper.jpg ]]; then
      use_wallpaper=true
    else
      wallpaper_tmp=$(mktemp "$sddm_cache_dir/.wallpaper.XXXXXX.jpg")
      if ffmpeg -loglevel error -y -i "$wallpaper" -frames:v 1 -q:v 2 "$wallpaper_tmp"; then
        mv -f -- "$wallpaper_tmp" "$sddm_cache_dir/vyeos-wallpaper.jpg"
        printf '%s\n' "$source_key" > "$sddm_cache_dir/wallpaper-source"
        use_wallpaper=true
      else
        rm -f -- "$wallpaper_tmp"
      fi
    fi
  fi

  config_tmp=$(mktemp "$sddm_cache_dir/.theme.XXXXXX.conf")
  write_sddm_theme "$file" "$config_tmp" "$use_wallpaper"
  mv -f -- "$config_tmp" "$sddm_cache_dir/theme.conf.user"
  chmod 644 "$sddm_cache_dir/theme.conf.user"
  [[ ! -f $sddm_cache_dir/vyeos-wallpaper.jpg ]] || chmod 644 "$sddm_cache_dir/vyeos-wallpaper.jpg"
}

sync_sddm_latest() {
  [[ -d $sddm_cache_dir && -w $sddm_cache_dir ]] || return 0
  exec 9>"$sddm_cache_dir/sync.lock"
  flock 9
  sync_sddm_theme "$(theme_file "$(current_theme)")"
}

schedule_sddm_sync() {
  [[ -d $sddm_cache_dir && -w $sddm_cache_dir ]] || return 0
  setsid -f "$0" sync-sddm-latest </dev/null >/dev/null 2>&1
}

apply_folder_icons() {
  local file=$1 color source_root icon_root theme_name size source_dir target_dir source name target
  color=$(jq -er '.applications.folder_color // "blue"' "$file")
  [[ $color =~ ^[A-Za-z0-9_-]+$ ]] || die "invalid folder color: $color"
  source_root=/usr/share/icons/Papirus-Dark
  icon_root=${XDG_DATA_HOME:-"$HOME/.local/share"}/icons
  theme_name=Vyeos-Papirus-Dark-$color
  [[ -d $source_root ]] || return 0

  if [[ ! -f $icon_root/$theme_name/.complete ]]; then
    mkdir -p "$icon_root/$theme_name"
    {
      printf '[Icon Theme]\nName=Vyeos Papirus Dark (%s)\nComment=Theme-managed Papirus folder colors\n' "$color"
      printf 'Inherits=Papirus-Dark,hicolor\nDirectories='
      local separator=
      for size in 16 22 24 32 48 64; do
        printf '%s%sx%s/places' "$separator" "$size" "$size"
        separator=,
      done
      printf '\n\n'
      for size in 16 22 24 32 48 64; do
        printf '[%sx%s/places]\nContext=Places\nSize=%s\nType=Fixed\n\n' "$size" "$size" "$size"
      done
    } > "$icon_root/$theme_name/index.theme"

    for size in 16 22 24 32 48 64; do
      source_dir=$(realpath -- "$source_root/${size}x${size}/places")
      target_dir=$icon_root/$theme_name/${size}x${size}/places
      mkdir -p "$target_dir"
      while IFS= read -r -d '' source; do
        [[ -L $source ]] && continue
        name=$(basename "$source")
        cp -- "$source" "$target_dir/$name"
        target=${name/-$color/}
        ln -sfn -- "$name" "$target_dir/$target"
      done < <(find -L "$source_dir" -maxdepth 1 -type f \( -name "folder-$color*.svg" -o -name "user-$color*.svg" \) -print0)
    done
    gtk-update-icon-cache -qf "$icon_root/$theme_name" >/dev/null 2>&1 || true
    : > "$icon_root/$theme_name/.complete"
  fi
  gsettings set org.gnome.desktop.interface icon-theme "$theme_name" >/dev/null 2>&1 || true
}

apply_alacritty_theme() {
  local file=$1 theme_name theme_path config_path resolved_config
  theme_name=$(jq -er '.applications.alacritty' "$file")
  [[ $theme_name =~ ^[A-Za-z0-9_-]+$ ]] || die "invalid Alacritty theme name: $theme_name"
  theme_path=$HOME/.config/alacritty/themes/themes/$theme_name.toml
  config_path=$HOME/.config/alacritty/alacritty.toml
  # Adapted for cool-shell: Alacritty is optional; skip instead of aborting apply.
  [[ -f $theme_path && -e $config_path ]] || { printf 'theme-system: skipping Alacritty (config not present)\n' >&2; return 0; }
  resolved_config=$(readlink -f -- "$config_path")
  sed -i "2c\\import = [\"~/.config/alacritty/themes/themes/$theme_name.toml\"]" "$resolved_config"
  rm -f -- "$cache_dir/alacritty.toml"
}

apply_fish_theme() {
  command -v fish >/dev/null || return 0
  fish -c 'source $argv[1]' "$cache_dir/fish.fish" >/dev/null 2>&1
}

write_generated_files() {
  local file=$1 slug name appearance
  slug=$(jq -er '.slug' "$file")
  name=$(jq -er '.name' "$file")
  appearance=$(jq -er '.appearance' "$file")
  mkdir -p "$cache_dir"

  jq -e '
    .colors as $c |
    ["bg_dim","bg0","bg1","bg2","bg3","bg4","primary_container",
     "secondary_container","foreground","muted","muted_dark","red","yellow",
     "green","primary","blue","aqua","orange","purple"] |
    all(. as $key | $c[$key] | strings | test("^#[0-9a-fA-F]{6}$"))
  ' "$file" >/dev/null || die "$slug has missing or invalid colors"

  local tmp
  tmp=$(mktemp -d "$cache_dir/.generate.XXXXXX")
  trap 'rm -rf -- "$tmp"' RETURN
  cp -- "$file" "$tmp/current.json"

  {
    printf 'return {\n  name = %s,\n  slug = %s,\n' \
      "$(jq -Rn --arg value "$name" '$value')" "$(jq -Rn --arg value "$slug" '$value')"
    while IFS=$'\t' read -r key value; do
      value=${value#\#}
      printf '  %s = "rgba(%see)",\n' "$key" "$value"
    done < <(jq -r '.colors | to_entries[] | [.key,.value] | @tsv' "$file")
    printf '}\n'
  } > "$tmp/hyprland.lua"

  {
    while IFS=$'\t' read -r key value; do
      printf '$%s = rgb(%s)\n' "$key" "${value#\#}"
    done < <(jq -r '.colors | to_entries[] | [.key,.value] | @tsv' "$file")
  } > "$tmp/hyprlock.conf"

  {
    printf '/* Generated from %s. */\n' "$slug"
    while IFS=$'\t' read -r key value; do
      printf '@define-color vyeos_%s %s;\n' "$key" "$value"
    done < <(jq -r '.colors | to_entries[] | [.key,.value] | @tsv' "$file")
    printf '\n@define-color accent_color @vyeos_primary;\n@define-color accent_bg_color @vyeos_primary;\n'
    printf '@define-color accent_fg_color @vyeos_bg_dim;\n@define-color destructive_color @vyeos_red;\n'
    printf '@define-color destructive_bg_color @vyeos_red;\n@define-color destructive_fg_color @vyeos_bg_dim;\n'
    printf '@define-color success_color @vyeos_green;\n@define-color warning_color @vyeos_yellow;\n@define-color error_color @vyeos_red;\n'
    printf '@define-color window_bg_color @vyeos_bg0;\n@define-color window_fg_color @vyeos_foreground;\n'
    printf '@define-color view_bg_color @vyeos_bg0;\n@define-color view_fg_color @vyeos_foreground;\n'
    printf '@define-color headerbar_bg_color @vyeos_bg1;\n@define-color headerbar_fg_color @vyeos_foreground;\n'
    printf '@define-color headerbar_border_color @vyeos_bg2;\n@define-color border_color @vyeos_bg2;\n'
    printf '@define-color popover_bg_color @vyeos_bg1;\n@define-color popover_fg_color @vyeos_foreground;\n'
    printf '@define-color tooltip_bg_color @vyeos_bg3;\n@define-color tooltip_fg_color @vyeos_foreground;\n'
    printf '@define-color sidebar_bg_color @vyeos_bg1;\n@define-color sidebar_fg_color @vyeos_foreground;\n'
    printf '@define-color menu_bg_color @vyeos_bg1;\n@define-color menu_fg_color @vyeos_foreground;\n'
    printf '@define-color card_bg_color @vyeos_bg1;\n@define-color card_fg_color @vyeos_foreground;\n'
  } > "$tmp/gtk.css"

  local primary foreground green aqua yellow red
  primary=$(jq -r '.colors.primary[1:]' "$file")
  foreground=$(jq -r '.colors.foreground[1:]' "$file")
  green=$(jq -r '.colors.green[1:]' "$file")
  aqua=$(jq -r '.colors.aqua[1:]' "$file")
  yellow=$(jq -r '.colors.yellow[1:]' "$file")
  red=$(jq -r '.colors.red[1:]' "$file")
  {
    printf 'set -Ux VYEOS_THEME %s\n' "$slug"
    printf 'set -Ux VYEOS_PRIMARY %s\n' "$primary"
    printf 'set -Ux EZA_COLORS "di=38;2;%s:fi=38;2;%s:ex=38;2;%s:ln=38;2;%s:or=38;2;%s"\n' \
      "$(printf '%d;%d;%d' "0x${green:0:2}" "0x${green:2:2}" "0x${green:4:2}")" \
      "$(printf '%d;%d;%d' "0x${foreground:0:2}" "0x${foreground:2:2}" "0x${foreground:4:2}")" \
      "$(printf '%d;%d;%d' "0x${primary:0:2}" "0x${primary:2:2}" "0x${primary:4:2}")" \
      "$(printf '%d;%d;%d' "0x${aqua:0:2}" "0x${aqua:2:2}" "0x${aqua:4:2}")" \
      "$(printf '%d;%d;%d' "0x${red:0:2}" "0x${red:2:2}" "0x${red:4:2}")"
    printf 'set -Ux VYEOS_PROMPT_PATH %s\nset -Ux VYEOS_PROMPT_MUTED %s\nset -Ux VYEOS_PROMPT_GIT %s\nset -Ux VYEOS_PROMPT_OK %s\nset -Ux VYEOS_PROMPT_ERROR %s\n' \
      "$aqua" "$(jq -r '.colors.muted_dark[1:]' "$file")" "$yellow" "$green" "$red"
  } > "$tmp/fish.fish"

  {
    printf 'vim.cmd("highlight clear")\nvim.o.termguicolors = true\nvim.g.colors_name = "vyeos-%s"\n' "$slug"
    while IFS=$'\t' read -r group fg bg extra; do
      printf 'vim.api.nvim_set_hl(0, "%s", {' "$group"
      [[ $fg != - ]] && printf ' fg = "%s",' "$(jq -r ".colors.$fg" "$file")"
      [[ $bg != - ]] && printf ' bg = "%s",' "$(jq -r ".colors.$bg" "$file")"
      [[ $extra != - ]] && printf ' %s = true,' "$extra"
      printf ' })\n'
    done <<'HIGHLIGHTS'
Normal	foreground	bg0	-
NormalFloat	foreground	bg1	-
FloatBorder	primary	bg1	-
Comment	muted_dark	-	italic
Identifier	blue	-	-
Function	green	-	-
Statement	purple	-	-
Keyword	purple	-	-
Type	yellow	-	-
String	green	-	-
Number	orange	-	-
Constant	orange	-	-
Special	aqua	-	-
Error	red	-	bold
Visual	-	bg3	-
Search	bg_dim	yellow	-
CursorLine	-	bg1	-
LineNr	muted_dark	-	-
CursorLineNr	primary	-	bold
Pmenu	foreground	bg1	-
PmenuSel	bg_dim	primary	-
StatusLine	foreground	bg2	-
DiagnosticError	red	-	-
DiagnosticWarn	yellow	-	-
DiagnosticInfo	blue	-	-
DiagnosticHint	aqua	-	-
HIGHLIGHTS
  } > "$tmp/nvim.lua"

  for generated in "$tmp"/*; do
    mv -f -- "$generated" "$cache_dir/$(basename "$generated")"
  done
  trap - RETURN
  rmdir -- "$tmp"

  mkdir -p "$state_dir" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  printf '%s\n' "$slug" > "$state_dir/current-theme"
  ln -sfn -- "$cache_dir/gtk.css" "$HOME/.config/gtk-3.0/vyeos-theme.css"
  ln -sfn -- "$cache_dir/gtk.css" "$HOME/.config/gtk-4.0/vyeos-theme.css"
  gsettings set org.gnome.desktop.interface color-scheme "prefer-$appearance" >/dev/null 2>&1 || true
}

set_wallpaper() {
  local path=${1:?wallpaper path required} sync=${2:-true} slug directory resolved
  slug=$(current_theme)
  directory=$wallpaper_root/$slug
  [[ -f $path ]] || die "wallpaper does not exist: $path"
  resolved=$(realpath -- "$path")
  mkdir -p "$live_wallpaper_dir"

  local in_theme=false in_live=false
  [[ $resolved == "$(realpath -m -- "$directory")/"* ]] && in_theme=true
  [[ $resolved == "$(realpath -m -- "$live_wallpaper_dir")/"* ]] && in_live=true

  if [[ $in_theme != true && $in_live != true ]]; then
    die "wallpaper is not in the $slug theme folder or live folder"
  fi

  if is_video_file "$resolved"; then
    qs -c cool-shell ipc call wallpaper setMedia "$resolved" "video" >/dev/null 2>&1 || qs ipc call wallpaper setMedia "$resolved" "video" >/dev/null 2>&1 || true
    awww clear "000000" >/dev/null 2>&1 || true
  else
    qs -c cool-shell ipc call wallpaper setMedia "" "image" >/dev/null 2>&1 || qs ipc call wallpaper setMedia "" "image" >/dev/null 2>&1 || true
    display_wallpaper "$resolved"
  fi

  mkdir -p "$state_dir"
  printf '%s\n' "$resolved" > "$state_dir/current-wallpaper"
  mkdir -p "$state_dir/wallpapers"
  printf '%s\n' "$resolved" > "$state_dir/wallpapers/$slug"
  [[ $sync != true ]] || schedule_sddm_sync
}

display_wallpaper() {
  local outputs= arguments=()
  if command -v hyprctl >/dev/null && command -v jq >/dev/null; then
    outputs=$(hyprctl monitors -j 2>/dev/null | jq -r 'map(.name) | join(",")' 2>/dev/null || true)
    [[ -z $outputs ]] || arguments+=(--outputs "$outputs")
  fi
  awww img "$1" "${arguments[@]}" \
    --transition-type center \
    --transition-duration 0.45 \
    --transition-fps 60
}

restore_wallpaper() {
  local slug directory saved first
  slug=$(current_theme)
  directory=$wallpaper_root/$slug
  mkdir -p "$live_wallpaper_dir"
  saved=
  if [[ -s $state_dir/wallpapers/$slug ]]; then
    IFS= read -r saved < "$state_dir/wallpapers/$slug"
  elif [[ -s $state_dir/current-wallpaper ]]; then
    IFS= read -r saved < "$state_dir/current-wallpaper"
  fi
  if [[ -n $saved && -f $saved ]]; then
    local real_saved
    real_saved=$(realpath -- "$saved")
    if [[ $real_saved == "$(realpath -m -- "$directory")/"* || $real_saved == "$(realpath -m -- "$live_wallpaper_dir")/"* ]]; then
      if is_video_file "$real_saved"; then
        qs -c cool-shell ipc call wallpaper setMedia "$real_saved" "video" >/dev/null 2>&1 || qs ipc call wallpaper setMedia "$real_saved" "video" >/dev/null 2>&1 || true
        awww clear "000000" >/dev/null 2>&1 || true
      else
        qs -c cool-shell ipc call wallpaper setMedia "" "image" >/dev/null 2>&1 || qs ipc call wallpaper setMedia "" "image" >/dev/null 2>&1 || true
        display_wallpaper "$real_saved"
      fi
      return
    fi
  fi
  first=$(find "$directory" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' \) -print -quit 2>/dev/null || true)
  if [[ -z $first ]]; then
    first=$(find "$live_wallpaper_dir" -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) -print -quit 2>/dev/null || true)
  fi
  if [[ -n $first ]]; then
    set_wallpaper "$first" false
  else
    awww clear "$(jq -r '.colors.bg0[1:]' "$(theme_file "$slug")")" >/dev/null 2>&1 || true
  fi
}

apply_theme() {
  local slug=$1 file nautilus_was_running=false
  file=$(theme_file "$slug")
  pgrep -x nautilus >/dev/null 2>&1 && nautilus_was_running=true
  write_generated_files "$file"
  apply_alacritty_theme "$file"
  apply_fish_theme
  apply_folder_icons "$file"
  hyprctl reload >/dev/null 2>&1 || true
  qs ipc call theme reload >/dev/null 2>&1 || true
  restore_wallpaper || true
  schedule_sddm_sync
  if $nautilus_was_running; then
    nautilus -q >/dev/null 2>&1 || true
    setsid -f nautilus >/dev/null 2>&1 || true
  fi
  command -v notify-send >/dev/null && notify-send "Theme changed" "$(jq -r .name "$file")" >/dev/null 2>&1 || true
}

case ${1:-} in
  apply) apply_theme "${2:?theme name required}" ;;
  current) current_theme ;;
  current-json) cat "$(theme_file "$(current_theme)")" ;;
  list) list_themes ;;
  wallpapers) list_wallpapers "${2:-}" ;;
  open-wallpapers) open_wallpaper_folder "${2:-}" ;;
  open-live-wallpapers) open_live_wallpaper_folder ;;
  wallpaper) set_wallpaper "${2:?wallpaper path required}" ;;
  restore-wallpaper) restore_wallpaper ;;
  sync-sddm-latest) sync_sddm_latest ;;
  generate) write_generated_files "$(theme_file "${2:-$(current_theme)}")" ;;
  *) die "usage: $0 {apply THEME|current|current-json|list|wallpapers [THEME]|open-wallpapers [THEME]|open-live-wallpapers|wallpaper PATH|restore-wallpaper|generate [THEME]}" ;;
esac

