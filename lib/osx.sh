#!/bin/sh
# OS X settings

defaults write com.apple.dock wvous-br-corner -int 5
defaults write com.apple.dock autohide -bool true
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
defaults write com.apple.screencapture location -string "${HOME}/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.finder EmptyTrashSecurely -bool true
defaults write com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode TwoButton

# iTerm 
defaults write com.googlecode.iterm2 HotKeyTogglesWindow -int 1
defaults write com.googlecode.iterm2 HotKey -int 1
defaults write com.googlecode.iterm2 HotkeyChar -int 96
defaults write com.googlecode.iterm2 HotkeyCode -int 50
defaults write com.googlecode.iterm2 HotkeyModifiers -int 262401

touch "$HOME_DIR/.hushlogin"
