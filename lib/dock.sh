# Remove all apps from the dock
dockutil --list | awk -F"\t" '{print $1}' | while read line; do 
  dockutil --remove "$line"
done

# Give dock time to restart
sleep 5

# Apps wanted in the dock, in order
apps=(Adium Atom "Google Chrome" Slack Spotify)

# Re-add the apps we want
for app in $apps; do 
  dockutil --add "/Applications/$app.app"
done
