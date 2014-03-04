#Boxen
source /opt/boxen/env.sh

# Git
alias gs="git status"
alias ga="git add"
alias go="git checkout"
alias gc="git commit"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"
alias gp="git push"
alias gd="git diff"
alias gb="git browse"
alias reset="git reset HEAD --hard; git clean -f"

#fasd
eval "$(fasd --init auto)"
alias j='fasd_cd -d'

#jekyll
alias jl="jekyll serve --watch"
alias jd="jekyll build --trace"

#subline
alias s='"/Applications/Sublime Text 2.app/Contents/SharedSupport/bin/subl"'
alias sp="s ./"
function js() { j "$@" ; sp; }
#export EDITOR='"/Applications/Sublime Text 2.app/Contents/SharedSupport/bin/subl" -w'

#atom
alias a='atom'
alias ap="a ./"
function js() { j "$@" ; ap; }
export EDITOR='atom -w'

# Chrome cors
alias chrome-cors="open -a Google\ Chrome --args --disable-web-security"

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

#simple server
alias server="python -m SimpleHTTPServer"

#ip
alias ip="curl icanhazip.com"
alias flushdns="dscacheutil -flushcache; echo 'Flushed DNS, btw here is your hosts file just in case:'; cat /etc/hosts"

#boxen + homebrew
alias up="boxen && brew update && brew upgrade"
