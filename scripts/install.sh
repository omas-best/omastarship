#!/usr/bin/env bash

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
bin_home=${OMASTARSHIP_BIN_HOME:-$HOME/.local/bin}
install_root="$data_home/omastarship"
bashrc=${OMASTARSHIP_BASHRC:-$HOME/.bashrc}
command_path="$bin_home/omastarship"
start_marker='# >>> omastarship >>>'
end_marker='# <<< omastarship <<<'

touch "$bashrc"
start_count=$(grep -Fxc "$start_marker" "$bashrc" || true)
end_count=$(grep -Fxc "$end_marker" "$bashrc" || true)
if [[ $start_count != "$end_count" || $start_count -gt 1 ]]; then
  printf 'install: malformed OmaStarship markers in %s; refusing to edit it\n' "$bashrc" >&2
  exit 1
fi

mkdir -p "$install_root/bin" "$install_root/shell" "$install_root/assets/sixel" "$install_root/assets/sixel-motion" "$config_home/omastarship" "$bin_home"

if [[ -L $command_path ]]; then
  if [[ $(readlink "$command_path") != "$install_root/bin/omastarship" ]]; then
    printf 'install: refusing to replace existing symlink: %s\n' "$command_path" >&2
    exit 1
  fi
elif [[ -e $command_path ]]; then
  printf 'install: refusing to replace existing file: %s\n' "$command_path" >&2
  exit 1
fi

install -m 0755 "$root/bin/omastarship" "$install_root/bin/omastarship"
install -m 0644 "$root/shell/omastarship.bash" "$install_root/shell/omastarship.bash"
install -m 0644 "$root/assets/rocket-concept-v2.png" "$install_root/assets/rocket-concept-v2.png"
install -m 0644 "$root"/assets/sixel/*.sixel "$install_root/assets/sixel/"
install -m 0644 "$root"/assets/sixel-motion/*.sixel "$install_root/assets/sixel-motion/"
if [[ ! -e $config_home/omastarship/config ]]; then
  install -m 0600 "$root/config.example" "$config_home/omastarship/config"
fi
ln -sfn "$install_root/bin/omastarship" "$command_path"

if [[ $start_count == 0 ]]; then
  backup=$(mktemp "${bashrc}.omastarship-backup.XXXXXX")
  cp -p "$bashrc" "$backup"
  {
    printf '\n%s\n' "$start_marker"
    printf '%s\n' 'if [[ -r "${XDG_DATA_HOME:-$HOME/.local/share}/omastarship/shell/omastarship.bash" ]]; then'
    printf '%s\n' '  source "${XDG_DATA_HOME:-$HOME/.local/share}/omastarship/shell/omastarship.bash"'
    printf '%s\n' 'fi'
    printf '%s\n' "$end_marker"
  } >> "$bashrc"
  printf 'Backed up %s to %s\n' "$bashrc" "$backup"
fi

printf 'Installed OmaStarship. Open a new terminal or run: source %q\n' "$bashrc"
