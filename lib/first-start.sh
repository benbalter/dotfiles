#!/bin/bash
# Opens apps for the first time to start the setup process

apps=(Cloak Cloudup "DNSCrypt Menubar" Dropbox Flux "Google Photos Backup" iTerm Yubiswitch)

for app in $apps; do
  open "/Applications/$app.app"
done
