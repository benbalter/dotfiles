# Remove all apps from the dock
dockutil --list | awk -F"\t" '{print $1}' | while read line; do 
  dockutil --remove "$line"
done

# Give dock time to restart
sleep 1

# Apps wanted in the dock, in order
apps=(Adium Atom "Google Chrome" Slack Spotify)

# Re-add the apps we want
for app in $apps; do 
  echo "adding $app to dock"
  dockutil --add "/Applications/$app.app"
  sleep 1
done
