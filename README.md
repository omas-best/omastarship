# OmaStarship

Turn Git pushes into rocket launches and Git pulls into booster catches.

![OmaStarship illustrated rocket states](assets/rocket-concept-v2.png)

The concept sheet shows ignition, launch, controlled descent, and the tower catch. The CLI demos below remain the source of truth for the terminal animation.

OmaStarship adds a short animation before interactive `git push` and `git pull` commands. It then gets out of the way and replaces itself with the real Git executable. Git receives the original argument array and direct access to stdin, stdout, and stderr.

## Try the demos

From this checkout:

```bash
./bin/omastarship demo push
./bin/omastarship demo pull
```

The default animation takes about one second. It uses the terminal's alternate screen, so the frames do not fill scrollback. Cleanup restores colors, cursor visibility, and the normal screen after completion or a handled signal.

## Install on Omarchy

The tested Omarchy 4.0.1 installation uses Bash and keeps user additions in `~/.bashrc`. Current upstream Omarchy also loads its defaults before a clearly marked user customization section in `.bashrc`. Its terminal selector supports Alacritty, Foot, Ghostty, and Kitty through `xdg-terminal-exec`. OmaStarship uses standard ANSI controls across those terminals instead of changing a terminal config.

Run:

```bash
./scripts/install.sh
```

The installer:

- copies the executable and shell integration under `${XDG_DATA_HOME:-$HOME/.local/share}/omastarship`
- creates a managed symlink at `${OMASTARSHIP_BIN_HOME:-$HOME/.local/bin}/omastarship`
- creates the config only when one does not exist
- backs up `.bashrc`, then adds one marked source block
- refuses to overwrite a non-symlink command named `omastarship`

Open a new terminal after installation. The installer can run again without adding a second shell block.

### Manual installation

Copy `bin/omastarship` somewhere on `PATH`. Then source `shell/omastarship.bash` near the end of your interactive Bash configuration:

```bash
source /absolute/path/to/omastarship/shell/omastarship.bash
```

The integration will not replace an existing `git` shell function. In that case, `omastarship status` reports `skipped-existing-git-function`, and Git remains untouched.

## Commands

```text
omastarship demo push
omastarship demo pull
omastarship enable
omastarship disable
omastarship status
omastarship config
```

Disable one command without editing config:

```bash
OMASTARSHIP=0 git push
```

`command git push` always bypasses the shell function and invokes Git directly.

## Configuration

The default path is `${XDG_CONFIG_HOME:-$HOME/.config}/omastarship/config`:

```ini
enabled=true
push_animation=true
pull_animation=true
speed=normal
colors=omarchy
show_status=true
```

Valid speeds are `fast`, `normal`, and `cinematic`. Valid color modes are `omarchy` and `none`. `NO_COLOR` also disables colors. Environment variables override the file for one process:

```text
OMASTARSHIP
OMASTARSHIP_PUSH_ANIMATION
OMASTARSHIP_PULL_ANIMATION
OMASTARSHIP_SPEED
OMASTARSHIP_COLORS
OMASTARSHIP_SHOW_STATUS
```

The `show_status` setting controls the final `CAUGHT` label in the pull animation. OmaStarship does not print a success message because Git has not run yet.

## Why a Bash function

A PATH wrapper would also affect scripts, IDEs, hooks, and other programs. Git aliases cannot transparently intercept the built-in `push` and `pull` names. Prompt hooks do not control execution or preserve an argument array.

The Bash function is narrower. It exists only in interactive shells that source it. It recognizes `push` or `pull`, including global options such as `git -C /path push`, without rewriting any argument. Unknown global options take the safe path and run Git without animation.

Animation runs only when stdin, stdout, and stderr are terminals. Redirected or piped commands skip it. After the preflight, `exec` gives the real Git process direct control, so credential helpers, SSH passphrase prompts, terminal prompts, errors, exit codes, and signals behave as they do without OmaStarship.

See [docs/architecture.md](docs/architecture.md) for the detailed safety model and tradeoffs.

## Uninstall

```bash
./scripts/uninstall.sh
```

The uninstaller backs up `.bashrc`, removes only the marked source block and managed installed files, and keeps the user config. Remove `${XDG_CONFIG_HOME:-$HOME/.config}/omastarship` yourself if you also want to discard settings.

## Development

Run the test suite and plugin manifest validator:

```bash
./tests/run.sh
./tests/git-integration.sh
python3 /home/kiwi/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .
```

Optional checks use `shellcheck` when it is installed:

```bash
shellcheck bin/omastarship shell/omastarship.bash scripts/*.sh tests/run.sh
```

The safety suite uses a fake Git executable to verify argument bytes, standard streams, failure statuses, prompt input, bypass behavior, terminal sizes, resize cleanup, colors, and reversible install/uninstall behavior. The integration suite uses temporary working repositories and a local bare remote for real pushes, pulls, rebases, force-with-lease, and failure paths. Neither suite contacts a network remote or claims to verify a real SSH server or credential helper.

## Current scope

This prototype supports Bash, the default shell on the inspected Omarchy 4.0.1 system. Zsh and Fish are not implemented. It has been exercised under a pseudo-terminal, not manually certified in every Omarchy terminal. The renderer uses common ANSI alternate-screen and cursor controls expected by the four terminal choices exposed by current Omarchy.

Research references:

- [Omarchy's current Bash user configuration layout](https://github.com/omacom/omarchy/blob/quattro/default/bashrc)
- [Omarchy's current terminal selector](https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-default-terminal)
- [Omarchy releases](https://github.com/omacom/omarchy/releases)

## License

MIT. See [LICENSE](LICENSE).
