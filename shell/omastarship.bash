# OmaStarship interactive Bash integration.
# shellcheck shell=bash

[[ $- == *i* ]] || return 0

if declare -F git >/dev/null 2>&1; then
  export OMASTARSHIP_SHELL_ACTIVE=skipped-existing-git-function
  return 0
fi

_omastarship_git_subcommand() {
  local arg
  while (($#)); do
    arg=$1
    case $arg in
      -C|-c|--git-dir|--work-tree|--namespace|--config-env)
        (($# >= 2)) || return 1
        shift 2
        ;;
      -C?*|-c?*|--git-dir=*|--work-tree=*|--namespace=*|--config-env=*)
        shift
        ;;
      --no-pager|--paginate|--no-replace-objects|--bare|--literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs|--no-optional-locks|--no-advice|-p|-P)
        shift
        ;;
      --help|-h|--version|-v|--exec-path|--html-path|--man-path|--info-path|--list-cmds=*|--attr-source=*|--)
        return 1
        ;;
      -*)
        return 1
        ;;
      *)
        printf '%s\n' "$arg"
        return 0
        ;;
    esac
  done
  return 1
}

git() {
  local git_bin subcommand omastarship_bin
  git_bin=$(type -P git) || {
    printf 'git: command not found\n' >&2
    return 127
  }

  subcommand=$(_omastarship_git_subcommand "$@") || {
    command "$git_bin" "$@"
    return
  }

  case $subcommand in
    push|pull) ;;
    *)
      command "$git_bin" "$@"
      return
      ;;
  esac

  omastarship_bin=${OMASTARSHIP_BIN:-}
  if [[ -z $omastarship_bin ]]; then
    omastarship_bin=$(type -P omastarship 2>/dev/null) || true
  fi
  if [[ -z $omastarship_bin || ! -x $omastarship_bin ]]; then
    command "$git_bin" "$@"
    return
  fi

  OMASTARSHIP_GIT_BIN=$git_bin command "$omastarship_bin" _exec-git "$subcommand" "$@"
}

export OMASTARSHIP_SHELL_ACTIVE=1
