#!/bin/bash

# Git
alias git="hub"
alias gs="git status"
alias ga="git add"
alias gad="git add ."
alias go="git checkout"
alias gc="git commit"
alias gcm="git commit -m"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"
alias gp="git push"
alias gd="git diff"
alias gb="git browse"
alias reset="git reset HEAD --hard; git clean -f -d"
alias clean="git branch --merged | grep -v '\*' | xargs -n 1 git branch -d"
alias ggb="git commit -m ':gem: bump'"

# fasd
alias j='fasd_cd -d'

# Script/*
alias sb="script/bootstrap"
alias sc="script/cibuild"
alias console="script/console"

#jekyll
alias jl="jekyll serve --watch"
alias jd="jekyll build --trace"

#atom
alias a='atom'
alias ap="a ./"
function ja() { j "$@" ; ap; }

#simple server
alias server="python -m SimpleHTTPServer"

#ip
alias ip="curl icanhazip.com"
alias flushdns="dscacheutil -flushcache; echo 'Flushed DNS, btw here is your hosts file just in case:'; cat /etc/hosts"

# .files
alias up="~/.files/script/update"
alias setup="~/.files/script/setup"

# Libre office
alias soffice="/Applications/LibreOffice.app/Contents/MacOS/soffice"
