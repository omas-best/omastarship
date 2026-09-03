# Architecture and safety model

OmaStarship chooses a short animation before Git starts. Running an animation beside Git would require multiplexing terminal output and deciding when to yield the screen for a password or host-key prompt. That is too risky for a cosmetic tool.

## Execution path

For an ordinary interactive Bash command:

```text
git function
  -> locate the executable with `type -P git`
  -> inspect global options without changing the argument array
  -> skip animation unless the subcommand is exactly push or pull
  -> skip animation unless file descriptors 0, 1, and 2 are TTYs
  -> run OmaStarship with the Git path and original arguments
  -> restore terminal state
  -> exec the Git executable with the original arguments
```

The last step replaces the animation process. There is no relay process between the terminal and Git.

## What stays untouched

OmaStarship does not write Git config or inspect repository state. It does not modify remotes, branches, commits, credentials, SSH configuration, or environment variables used by Git. The shell function passes `"$@"` unchanged.

`command git`, non-interactive shells, scripts that do not source the integration, and IDE processes keep using the original Git executable. The function also declines to install itself over an existing `git` function.

## Terminal cleanup

The renderer enters the alternate screen and hides the cursor. One cleanup function resets graphic attributes, shows the cursor, and leaves the alternate screen. `EXIT`, `INT`, `TERM`, and `HUP` handlers call it. `WINCH` marks the dimensions stale, and the next frame reads the new terminal size.

If the alternate screen cannot open, the renderer returns and Git still runs. If the user interrupts the animation, the handler restores the screen and exits with the conventional signal status. Git does not start after an interrupted preflight.

## Parser behavior

The shell function recognizes common Git global flags, including value-bearing forms such as `-C`, `-c`, `--git-dir`, `--work-tree`, `--namespace`, and `--config-env`. It animates only when it can identify the subcommand without guessing. An unknown global option bypasses animation and goes straight to Git, which remains responsible for parsing and reporting errors.

## Known limits

- Bash only. Zsh and Fish need native integration files and their own tests.
- The preflight adds about 0.9 seconds at normal speed before Git starts.
- Interrupting the preflight cancels the whole command.
- Alternate-screen behavior has automated pseudo-terminal coverage. It has not been checked by hand in every Omarchy-supported terminal.
- A user alias named `git` can take precedence before the function is reached. OmaStarship does not remove aliases.
- If a future Git release adds a new global option before `push` or `pull`, that form runs safely without animation until the parser learns it.
