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
