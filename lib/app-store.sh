#!/bin/sh

apps=("com.apple.Terminal" "com.apple.appstore" "com.googlecode.iterm2")

for app in "${apps[@]}"; do
  sudo /usr/local/bin/tccutil --insert "$app"
  sudo /usr/local/bin/tccutil --enable "$app"
done

osascript < "./lib/app-store.applescript"

for app in "${apps[@]}"; do
  sudo /usr/local/bin/tccutil --remove "$app"
done
