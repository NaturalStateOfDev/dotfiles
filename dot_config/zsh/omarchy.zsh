# Omarchy's shell helpers, loaded under zsh.
#
# Omarchy ships a substantial bash rc ($OMARCHY_PATH/default/bash/*) that its
# docs, menus, and tmux/herdr layouts all assume exists. We run zsh, so we
# can't source that rc wholesale — parts of it are bash-only. This file
# cherry-picks the portable parts and skips the rest.
#
# Sourced EARLY in .zshrc (right after oh-my-zsh) on purpose: anything defined
# here can be overridden by our own aliases further down. On a name clash
# (`ls`, `lt`) ours wins, which is the intent — we want Omarchy's *unique*
# helpers, not its opinions about ls.
#
# Everything is guarded: on a machine without Omarchy this file returns
# immediately rather than erroring.

[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] || return 0
source /usr/share/omarchy/default/bash/env-bootstrap
: "${OMARCHY_PATH:=/usr/share/omarchy}"

_omarchy_zsh_source() { [[ -r "$1" ]] && source "$1"; }

# ---------------------------------------------------------------- exports
# EDITOR/SUDO_EDITOR/BROWSER wired to omarchy-launch-*, bat-colored man pages,
# locale repair for non-login shells. Plain exports, portable as-is.
_omarchy_zsh_source "$OMARCHY_PATH/default/bash/envs"

# --------------------------------------------------------------- aliases
# .. / ... / t / g / n / d / h / mup / ff / eff / open / zd, etc.
_omarchy_zsh_source "$OMARCHY_PATH/default/bash/aliases"

# ----------------------------------------------------- function libraries
# Portable: POSIX-ish parameter expansion, no bash-only builtins, no
# 0-indexed array access.
#   compression          compress / decompress
#   ssh-port-forwarding  fip / dip / lip
#   rsyncing             rsw / lsw / dsw
#   worktrees            ga / gd
#   ssh-reconnect        ssh wrapper that disarms terminal modes on a drop
for _f in compression ssh-port-forwarding rsyncing worktrees ssh-reconnect; do
  _omarchy_zsh_source "$OMARCHY_PATH/default/bash/fns/$_f"
done

# These index arrays from 0 (`${panes[0]}`, `${columns[-1]}`), which is bash
# semantics — zsh arrays start at 1, so `[0]` would come back empty. zsh's
# sticky emulation makes functions DEFINED inside `emulate ksh -c` keep ksh
# array semantics whenever they're later called from our normal zsh session.
#   tmux    tdl / tds / tdlm / tsl
#   herdr   hdl / hds / hdlm / hsl
for _f in tmux herdr; do
  [[ -r "$OMARCHY_PATH/default/bash/fns/$_f" ]] &&
    emulate ksh -c "source '$OMARCHY_PATH/default/bash/fns/$_f'"
done

# ------------------------------------------------------------- NOT loaded
# default/bash/shell        `shopt`, bash-completion — no zsh equivalent
# default/bash/init         `mise activate bash`, `starship init bash`,
#                           `zoxide init bash`, fzf *.bash — .zshrc already
#                           runs the zsh variants of every one of these
# default/bash/completions  bash `complete -F`
# default/bash/inputrc      readline; zsh uses ZLE
#
# fns/drives (iso2sd, format-drive) is skipped: it prompts with `read -rp`,
# which is a bash-only spelling. Run those two under bash if you need them.

unset -f _omarchy_zsh_source
unset _f
