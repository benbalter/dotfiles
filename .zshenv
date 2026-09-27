# Debian and Ubuntu's /etc/zsh/zshrc runs its own compinit before ~/.zshrc
# unless this is set. oh-my-zsh runs compinit anyway, with
# ZSH_DISABLE_COMPFIX. The global one audited GitHub's Ubuntu runner, found
# insecure directories and, with no terminal to ask on, aborted with
# "compinit: initialization aborted". Harmless elsewhere: macOS's /etc/zshrc
# doesn't run compinit.
skip_global_compinit=1
