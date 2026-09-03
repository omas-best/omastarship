#!/usr/bin/env bash

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export OMASTARSHIP_BIN="$root/bin/omastarship"
export OMASTARSHIP=0

wrapped_git() {
  bash --noprofile --norc -ic 'source "$1"; shift; git "$@"' bash "$root/shell/omastarship.bash" "$@"
}

quiet_wrapped_git() {
  wrapped_git "$@" >/dev/null 2>&1
}

git init --bare -q "$tmp/remote.git"
git init -q -b main "$tmp/work"
git -C "$tmp/work" config user.name 'OmaStarship Test'
git -C "$tmp/work" config user.email 'omastarship@example.invalid'
printf 'one\n' > "$tmp/work/story.txt"
git -C "$tmp/work" add story.txt
git -C "$tmp/work" commit -qm 'one'
git -C "$tmp/work" remote add origin "$tmp/remote.git"

cd "$tmp/work"
quiet_wrapped_git push -u origin main
printf 'two\n' >> story.txt
git add story.txt
git commit -qm 'two'
quiet_wrapped_git push
quiet_wrapped_git push origin main
quiet_wrapped_git push --force-with-lease

git clone -q -b main "$tmp/remote.git" "$tmp/peer"
git -C "$tmp/peer" config user.name 'OmaStarship Peer'
git -C "$tmp/peer" config user.email 'peer@example.invalid'

printf 'three\n' >> "$tmp/peer/story.txt"
git -C "$tmp/peer" commit -qam 'three'
git -C "$tmp/peer" push -q
quiet_wrapped_git pull

printf 'four\n' >> "$tmp/peer/story.txt"
git -C "$tmp/peer" commit -qam 'four'
git -C "$tmp/peer" push -q
quiet_wrapped_git pull --rebase

printf 'five\n' >> "$tmp/peer/story.txt"
git -C "$tmp/peer" commit -qam 'five'
git -C "$tmp/peer" push -q
quiet_wrapped_git pull origin main

if quiet_wrapped_git push missing-remote main; then
  printf 'failed push unexpectedly succeeded\n' >&2
  exit 1
fi

if quiet_wrapped_git pull missing-remote main; then
  printf 'failed pull unexpectedly succeeded\n' >&2
  exit 1
fi

cmp "$tmp/work/story.txt" "$tmp/peer/story.txt"
printf 'Real Git integration passed.\n'
