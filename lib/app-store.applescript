#!/usr/bin/osascript

-- List of app store apps to install, if not installed
-- Name must exactly match name as it appears on the "Purchased" tab of the App Store
set myApps to {"Chroma for Hue", "Pushbullet", "Thessa", "TweetDeck by Twitter", "Calca", "GIF Brewery", "Twitter"}

-- via http://stackoverflow.com/a/3469708
on FileExists(theFile) -- (String) as Boolean
	tell application "System Events"
		if exists file theFile then
			return true
		else
			return false
		end if
	end tell
end FileExists

-- via http://www.macosxautomation.com/applescript/sbrt/sbrt-06.html
on replace_chars(this_text, search_string, replacement_string)
	set AppleScript's text item delimiters to the search_string
	set the item_list to every text item of this_text
	set AppleScript's text item delimiters to the replacement_string
	set this_text to the item_list as string
	set AppleScript's text item delimiters to ""
	return this_text
end replace_chars

tell application "App Store" to activate
delay 1
tell application "System Events" to tell process "App Store"
	click menu item "Purchased" of menu "Store" of menu bar 1
	delay 3

	-- iterate through apps in the table
	set appTable to table 1 of UI element 1 of scroll area 1 of group 1 of group 1 of window "App Store"
	repeat with appRow in rows in appTable

		-- Get the app's name
		-- For some reasons, different apps are structured differently in the DOM. *shrug* and code around it.
		if (count of UI elements of appRow) is 4 then
			if class of UI element 1 of group 1 of UI element 1 of appRow is image then
				if class of UI element 1 of group 1 of group 2 of UI element 1 of appRow is static text then
					set appName to value of UI element 1 of group 1 of group 2 of UI element 1 of appRow
				else
					set appName to value of UI element 1 of UI element 1 of UI element 1 of group 1 of group 2 of UI element 1 of appRow
				end if
			else
				set appName to value of UI element 1 of UI element 1 of UI element 1 of group 1 of group 1 of UI element 1 of appRow
			end if

			-- Is this an app that we want installed?
			if appName is in myApps then

				-- There's no clean way to detect if an app is installed;
				-- The Open vs. install you see in the UI isnt' installed programatically
				-- Instead, try to guess the app's filename and check if it's in the Applications folder
				set filePath to "/Applications/" & (the first word of appName) & ".app"
				set filePath2 to my replace_chars("/Applications/" & appName & ".app", " ", "")
				if my FileExists(filePath) or my FileExists(filePath2) then
					set appInstalled to true
					log appName & " already installed. Skipping"

				else
					set appInstalled to false
					log "Installing " & appName
				end if

				-- App isn't installed, we want it installed, lets do this thing...
				if appInstalled is false then
					-- Again, different apps are structured differently. Code around.
					if class of UI element 1 of UI element 4 of appRow is button then
						set appButton to button 1 of UI element 4 of appRow
					else
						set appButton to button 1 of group 1 of UI element 4 of appRow
					end if

					click appButton
				end if
			end if
		end if
	end repeat
end tell

tell application "App Store" to quit
