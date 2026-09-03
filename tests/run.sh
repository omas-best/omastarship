#!/usr/bin/env bash

set -u

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
passes=0
failures=0

pass() { printf 'ok - %s\n' "$1"; passes=$((passes + 1)); }
fail() { printf 'not ok - %s\n' "$1"; failures=$((failures + 1)); }

assert_status() {
  local name=$1 expected=$2 actual=$3
  if [[ $actual == "$expected" ]]; then pass "$name"; else fail "$name (expected $expected, got $actual)"; fi
}

assert_contains() {
  local name=$1 file=$2 text=$3
  if grep -Fq -- "$text" "$file"; then pass "$name"; else fail "$name (missing: $text)"; fi
}

mkdir -p "$tmp/fake-bin" "$tmp/config"
fake_git="$tmp/fake-bin/git"
cat > "$fake_git" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" > "${FAKE_GIT_LOG:?}"
printf 'git-stdout\n'
printf 'git-stderr\n' >&2
if [[ ${FAKE_GIT_PROMPT:-0} == 1 ]]; then
  printf 'Passphrase: ' > /dev/tty
  IFS= read -r answer < /dev/tty
  printf 'accepted:%s\n' "$answer"
fi
if [[ ${FAKE_GIT_STDIN:-0} == 1 ]]; then
  IFS= read -r answer
  printf 'stdin:%s\n' "$answer"
fi
if [[ ${FAKE_GIT_WAIT:-0} == 1 ]]; then
  trap 'exit 77' INT
  while :; do sleep 1; done
fi
exit "${FAKE_GIT_STATUS:-0}"
EOF
chmod +x "$fake_git"

run_wrapped() {
  local out=$1 err=$2
  shift 2
  PATH="$tmp/fake-bin:$PATH" \
    OMASTARSHIP_BIN="$root/bin/omastarship" \
    FAKE_GIT_LOG="$tmp/args" \
    XDG_CONFIG_HOME="$tmp/config" \
    bash --noprofile --norc -ic 'source "$1"; shift; git "$@"' bash "$root/shell/omastarship.bash" "$@" > "$out" 2> "$err"
}

check_args() {
  local name=$1
  shift
  printf '%s\0' "$@" > "$tmp/expected"
  if cmp -s "$tmp/expected" "$tmp/args"; then pass "$name"; else fail "$name (arguments changed)"; fi
}

run_wrapped "$tmp/out" "$tmp/err" push
assert_status 'git push exit code' 0 "$?"
check_args 'git push arguments' push
if grep -Fq $'\033[?1049h' "$tmp/out" "$tmp/err"; then fail 'redirected output skips animation'; else pass 'redirected output skips animation'; fi

run_wrapped "$tmp/out" "$tmp/err" push origin main
check_args 'git push origin main arguments' push origin main

run_wrapped "$tmp/out" "$tmp/err" push --force-with-lease
check_args 'git push --force-with-lease arguments' push --force-with-lease

run_wrapped "$tmp/out" "$tmp/err" pull
check_args 'git pull arguments' pull

run_wrapped "$tmp/out" "$tmp/err" pull --rebase
check_args 'git pull --rebase arguments' pull --rebase

run_wrapped "$tmp/out" "$tmp/err" pull origin main
check_args 'git pull origin main arguments' pull origin main

run_wrapped "$tmp/out" "$tmp/err" -C '/tmp/a path' push origin 'topic branch'
check_args 'git -C path push preserves every argument' -C '/tmp/a path' push origin 'topic branch'

FAKE_GIT_STATUS=41 run_wrapped "$tmp/out" "$tmp/err" push
assert_status 'failed push exit code' 41 "$?"
assert_contains 'failed push keeps stderr' "$tmp/err" 'git-stderr'

FAKE_GIT_STATUS=42 run_wrapped "$tmp/out" "$tmp/err" pull
assert_status 'failed pull exit code' 42 "$?"
assert_contains 'failed pull keeps stdout' "$tmp/out" 'git-stdout'

printf 'credential-value\n' | PATH="$tmp/fake-bin:$PATH" OMASTARSHIP_BIN="$root/bin/omastarship" FAKE_GIT_LOG="$tmp/args" FAKE_GIT_STDIN=1 XDG_CONFIG_HOME="$tmp/config" bash --noprofile --norc -ic 'source "$1"; git pull' bash "$root/shell/omastarship.bash" > "$tmp/out" 2> "$tmp/err"
assert_contains 'piped stdin reaches Git' "$tmp/out" 'stdin:credential-value'

printf 'ssh-secret\n' | TERM=xterm-256color PATH="$tmp/fake-bin:$PATH" OMASTARSHIP_BIN="$root/bin/omastarship" OMASTARSHIP_TEST_NO_SLEEP=1 FAKE_GIT_LOG="$tmp/args" FAKE_GIT_PROMPT=1 XDG_CONFIG_HOME="$tmp/config" script -qefc "bash --noprofile --norc -ic 'source \"$root/shell/omastarship.bash\"; git push'" "$tmp/prompt.typescript" >/dev/null
assert_status 'TTY prompt command exits normally' 0 "$?"
assert_contains 'SSH-style prompt can read terminal' "$tmp/prompt.typescript" 'accepted:ssh-secret'

PATH="$tmp/fake-bin:$PATH" OMASTARSHIP_BIN="$root/bin/omastarship" FAKE_GIT_LOG="$tmp/args" bash --noprofile --norc -ic 'source "$1"; command git status; type -P git; type -t git' bash "$root/shell/omastarship.bash" > "$tmp/out" 2> "$tmp/err"
assert_contains 'command git bypasses animation wrapper' "$tmp/out" 'git-stdout'
assert_contains 'original Git executable remains discoverable' "$tmp/out" "$fake_git"
assert_contains 'interactive git command is a function' "$tmp/out" 'function'

PATH="$tmp/fake-bin:$PATH" OMASTARSHIP_BIN="$tmp/missing" FAKE_GIT_LOG="$tmp/args" bash --noprofile --norc -ic 'source "$1"; git push fallback' bash "$root/shell/omastarship.bash" > "$tmp/out" 2> "$tmp/err"
assert_status 'missing animator falls back to Git' 0 "$?"
check_args 'fallback keeps arguments' push fallback

TERM=xterm-256color OMASTARSHIP_TEST_NO_SLEEP=1 script -qefc "stty rows 24 cols 80; '$root/bin/omastarship' demo push" "$tmp/push.typescript" >/dev/null
assert_status '80x24 push demo' 0 "$?"
assert_contains 'push enters alternate screen' "$tmp/push.typescript" $'\033[?1049h'
assert_contains 'push restores alternate screen' "$tmp/push.typescript" $'\033[?1049l'

TERM=foot OMASTARSHIP_GRAPHICS=auto OMASTARSHIP_TEST_NO_SLEEP=1 script -qefc "stty rows 24 cols 80; '$root/bin/omastarship' demo push" "$tmp/push-sixel.typescript" >/dev/null
assert_status 'Foot illustrated push demo' 0 "$?"
assert_contains 'Foot push emits packaged Sixel art' "$tmp/push-sixel.typescript" $'\033P0;1;0q'
if grep -Fq '| OM |' "$tmp/push-sixel.typescript"; then fail 'Foot push avoids ASCII rocket'; else pass 'Foot push avoids ASCII rocket'; fi

TERM=foot OMASTARSHIP_GRAPHICS=auto OMASTARSHIP_TEST_NO_SLEEP=1 script -qefc "stty rows 24 cols 80; '$root/bin/omastarship' demo pull" "$tmp/pull-sixel.typescript" >/dev/null
assert_status 'Foot illustrated pull demo' 0 "$?"
assert_contains 'Foot pull emits packaged Sixel art' "$tmp/pull-sixel.typescript" $'\033P0;1;0q'
assert_contains 'illustrated pull keeps catch label' "$tmp/pull-sixel.typescript" 'CAUGHT'

TERM=xterm-256color OMASTARSHIP_TEST_NO_SLEEP=1 script -qefc "stty rows 50 cols 160; '$root/bin/omastarship' demo pull" "$tmp/pull.typescript" >/dev/null
assert_status 'large pull demo' 0 "$?"
assert_contains 'pull renders catch state' "$tmp/pull.typescript" 'CAUGHT'

TERM=xterm-256color OMASTARSHIP_TEST_NO_SLEEP=1 script -qefc "stty rows 8 cols 32; '$root/bin/omastarship' demo pull" "$tmp/small.typescript" >/dev/null
assert_status 'small terminal fallback' 0 "$?"
assert_contains 'small terminal uses compact frame' "$tmp/small.typescript" 'PULL  [ catch  ]'

TERM=xterm-256color NO_COLOR=1 OMASTARSHIP_TEST_NO_SLEEP=1 script -qefc "'$root/bin/omastarship' demo push" "$tmp/no-color.typescript" >/dev/null
if grep -Fq $'\033[38;5;' "$tmp/no-color.typescript"; then fail 'NO_COLOR removes palette escapes'; else pass 'NO_COLOR removes palette escapes'; fi

TERM=xterm-256color OMASTARSHIP_SPEED=cinematic script -qefc "stty rows 24 cols 80; (sleep 0.3; stty rows 30 cols 100 < /dev/tty) & exec '$root/bin/omastarship' demo pull" "$tmp/resize.typescript" >/dev/null
assert_status 'terminal resize during animation' 0 "$?"
assert_contains 'resize run restores terminal' "$tmp/resize.typescript" $'\033[?1049l'

TERM=xterm-256color OMASTARSHIP_SPEED=cinematic script -qefc "(sleep 0.3; kill -INT \$\$) & exec '$root/bin/omastarship' demo push" "$tmp/animation-int.typescript" >/dev/null
animation_int_status=$?
assert_status 'Ctrl+C during animation returns 130' 130 "$animation_int_status"
assert_contains 'Ctrl+C during animation restores terminal' "$tmp/animation-int.typescript" $'\033[?1049l'

TERM=xterm-256color OMASTARSHIP_TEST_NO_SLEEP=1 OMASTARSHIP_GIT_BIN="$fake_git" FAKE_GIT_LOG="$tmp/args" FAKE_GIT_WAIT=1 script -qefc "(sleep 0.3; kill -INT \$\$) & exec '$root/bin/omastarship' _exec-git push push" "$tmp/git-int.typescript" >/dev/null
git_int_status=$?
assert_status 'Ctrl+C reaches Git after animation' 77 "$git_int_status"
assert_contains 'terminal restored before interrupted Git' "$tmp/git-int.typescript" $'\033[?1049l'

home="$tmp/home"
mkdir -p "$home"
printf '# existing bashrc\n' > "$home/.bashrc"
HOME="$home" XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" "$root/scripts/install.sh" > "$tmp/install.out"
HOME="$home" XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" "$root/scripts/install.sh" >> "$tmp/install.out"
if [[ $(grep -Fc '# >>> omastarship >>>' "$home/.bashrc") == 1 ]]; then pass 'installer is idempotent'; else fail 'installer duplicated shell block'; fi
if [[ -x $home/.local/bin/omastarship ]]; then pass 'installer creates command'; else fail 'installer did not create command'; fi
if [[ -s $home/.local/share/omastarship/assets/sixel/launch.sixel ]]; then pass 'installer includes illustrated frames'; else fail 'installer omitted illustrated frames'; fi
HOME="$home" XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" "$root/scripts/uninstall.sh" > "$tmp/uninstall.out"
if grep -Fq '# >>> omastarship >>>' "$home/.bashrc"; then fail 'uninstaller left shell block'; else pass 'uninstaller removes shell block'; fi
if [[ -e $home/.local/bin/omastarship ]]; then fail 'uninstaller left command'; else pass 'uninstaller removes command'; fi
if [[ -f $home/.config/omastarship/config ]]; then pass 'uninstaller preserves user config'; else fail 'uninstaller removed user config'; fi
if [[ -e $home/.local/share/omastarship/assets/sixel/launch.sixel ]]; then fail 'uninstaller left illustrated frames'; else pass 'uninstaller removes illustrated frames'; fi

printf '\n%d passed, %d failed\n' "$passes" "$failures"
((failures == 0))
