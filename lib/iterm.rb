#!/usr/bin/env ruby
# Sets iTerm2 preferences

require 'CFPropertyList'

# Per profile preferences
profile_preferences = {
  "Prompt Before Closing 2" => 0,
  "Blend"                   => 0.5,
  "Scrollback Lines"        => 0,
  "Unlimited Scrollback"    => true,
  "Normal Font"             => "Inconsolata 16",
  "Non Ascii Font"          => "Inconsolata 16",
  "Transparency"            => 0.30,
  "Custom Directory"        => "Recycle"
}

file = File.expand_path "~/Library/Preferences/com.googlecode.iterm2.plist"
plist = CFPropertyList::List.new file: file
data = CFPropertyList.native_types(plist.value)

hotkey_profile = data["New Bookmarks"].find { |p| p["Name"] == "Hotkey Window"}
preferences["HotKeyBookmark"] = hotkey_profile["Guid"]

data["New Bookmarks"].each do |profile|
  profile_preferences.each do |key, value|
    profile[key] = value
  end
end

plist.value = CFPropertyList.guess(data, :convert_unknown_to_string => true)
plist.save file, CFPropertyList::List::FORMAT_BINARY
