# Personal aliases — auto-sourced by oh-my-zsh (any *.zsh in $ZSH_CUSTOM).
#
# Naming scheme, built to grow without colliding with omz plugins:
#
#   1. Workflow aliases = one-letter tool prefix + a real short word.
#        g = git        gsync, gfresh, gnuke
#        d = docker     dclean, dsh
#        k = kubectl    kctx, klogs
#        t = terraform  tplan, tapply
#      Words, not abbreviations: self-documenting, and the terse space
#      (gcm, gl, gst, gwip, ...) is already owned by omz plugins.
#   2. Before claiming a name, confirm it's free:  type <name>
#   3. If it needs arguments in the middle of the command, write a
#      function here instead of an alias.

# --- git ---
# Jump to the default branch (main/master/trunk — omz detects it) and pull.
alias gsync='git checkout "$(git_main_branch)" && git pull'

# --- nix ---
# Full NixOS update in one go: bump flake inputs, check for a newer GE-Proton
# release (the flake's own updater, since flake inputs can't track GitHub
# releases), then rebuild + switch. Prints the diff of what changed first so
# a surprise bump is visible before the switch. Override the flake location
# with $NIXOS_FLAKE (defaults to ~/myNixOS).
nupdate() {
  local flake="${NIXOS_FLAKE:-$HOME/myNixOS}"
  [[ -f "$flake/flake.nix" ]] || { echo "nupdate: no flake at $flake" >&2; return 1; }
  (
    set -e
    cd "$flake"
    nix flake update
    nix run .#update-proton-ge
    git --no-pager diff --stat
    sudo nixos-rebuild switch --flake .
  )
}
