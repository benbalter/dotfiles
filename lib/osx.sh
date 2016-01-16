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
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Software update
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool TRUE
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdateRestartRequired -bool TRUE
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool TRUE

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

# SNap to grid
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# Enable safari webinspector
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

touch "$HOME_DIR/.hushlogin"
