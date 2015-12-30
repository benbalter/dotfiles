#!/usr/bin/env ruby
# Sets Chrome preferences

require 'json'

file = File.expand_path "~/Library/Application Support/Google/Chrome/Default/Preferences"
json = File.open(file).read
prefs = JSON.parse(json)

prefs["autofill"]["enabled"] = false
prefs["enable_do_not_track"] = true
prefs["profile"]["password_manager_enabled"] = false
prefs["plugins"]["plugins_list"].select { |p| p["name"] =~ /\bFlash\b/}.each do |p|
  p["enabled"] = false
end

File.write(file, prefs.to_json)
