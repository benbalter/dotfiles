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

# screensaver
if [[ ! -d "$HOME_DIR/github/octodex.github.com" ]]; then
  git clone https://github.com/github/octodex.github.com "$HOME_DIR/github/octodex.github.com"
fi
defaults -currentHost write com.apple.screensaver moduleDict -dict moduleName "iLifeSlideshows" path "/System/Library/Frameworks/ScreenSaver.framework/Resources/iLifeSlideshows.saver" type -int 0
defaults -currentHost write com.apple.ScreenSaver.iLifeSlideShows styleKey "VintagePrints"
defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedFolderPath "/Users/benbalter/github/octodex.github.com/images"
defaults -currentHost write com.apple.ScreenSaverPhotoChooser CustomFolderDict -dict identifier "/Users/benbalter/github/octodex.github.com/images" name "octodex"
defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedFolderPath "/Users/benbalter/github/octodex.github.com/images"
defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedSource -int 4

touch "$HOME_DIR/.hushlogin"
