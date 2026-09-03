#!/usr/bin/env bash

set -euo pipefail

data_home=${XDG_DATA_HOME:-$HOME/.local/share}
bin_home=${OMASTARSHIP_BIN_HOME:-$HOME/.local/bin}
install_root="$data_home/omastarship"
bashrc=${OMASTARSHIP_BASHRC:-$HOME/.bashrc}
command_path="$bin_home/omastarship"
start_marker='# >>> omastarship >>>'
end_marker='# <<< omastarship <<<'

if [[ -f $bashrc ]]; then
  start_count=$(grep -Fxc "$start_marker" "$bashrc" || true)
  end_count=$(grep -Fxc "$end_marker" "$bashrc" || true)
else
  start_count=0
  end_count=0
fi
if [[ $start_count != "$end_count" || $start_count -gt 1 ]]; then
  printf 'uninstall: malformed OmaStarship markers in %s; refusing to edit it\n' "$bashrc" >&2
  exit 1
fi
if [[ $start_count == 1 ]]; then
  backup=$(mktemp "${bashrc}.omastarship-backup.XXXXXX")
  cp -p "$bashrc" "$backup"
  tmp=$(mktemp "${bashrc}.omastarship.XXXXXX")
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$bashrc" > "$tmp"
  chmod --reference="$bashrc" "$tmp"
  mv "$tmp" "$bashrc"
  printf 'Removed shell block. Backup: %s\n' "$backup"
fi

if [[ -L $command_path ]]; then
  target=$(readlink "$command_path")
  if [[ $target == "$install_root/bin/omastarship" ]]; then
    rm "$command_path"
  fi
fi

rm -f "$install_root/bin/omastarship" "$install_root/shell/omastarship.bash"
rmdir "$install_root/bin" "$install_root/shell" "$install_root" 2>/dev/null || true

printf 'Uninstalled OmaStarship. User configuration was kept in %s.\n' "${XDG_CONFIG_HOME:-$HOME/.config}/omastarship"
