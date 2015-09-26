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

#atom
alias a='atom'
alias ap="a ./"
function ja() { j "$@" ; ap; }
export EDITOR='atom -w'

# Chrome cors
alias chrome-cors="open -a Google\ Chrome --args --disable-web-security"

#simple server
alias server="python -m SimpleHTTPServer"

#ip
alias ip="curl icanhazip.com"
alias flushdns="dscacheutil -flushcache; echo 'Flushed DNS, btw here is your hosts file just in case:'; cat /etc/hosts"

#php cli
export MAMP_PHP_VERSION="5.6.2"
alias php="/Applications/MAMP/bin/php/php$MAMP_PHP_VERSION/bin/php"
export WP_CLI_PHP="/Applications/MAMP/bin/php/php$MAMP_PHP_VERSION/bin/php"
alias composer="php /Applications/MAMP/bin/php/php$MAMP_PHP_VERSION/bin/composer.phar"
alias phpunit="php /Applications/MAMP/bin/php/php$MAMP_PHP_VERSION/bin/phpunit.phar"
alias wp="php /Applications/MAMP/bin/php/php$MAMP_PHP_VERSION/bin/wp-cli.phar"

# GPG - Workaround for https://github.com/keybase/keybase-issues/issues/1214
export GPG_TTY=`tty`

# Libre office
alias soffice="/Applications/LibreOffice.app/Contents/MacOS/soffice"

# You've got mail
unset MAILCHECK

# .files
alias up="~/.files/script/update"

rbenv rehash
